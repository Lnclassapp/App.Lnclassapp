# 🧠 DOMAINE · UseCases::Classroom::RegisterStudent
# Rôle : un visiteur crée son compte élève (rôle imposé) et entre tout de suite dans la classe choisie ou celle de son lien, en une transaction
# ADR  : 0026, 0028, 0040, 0041, 0050, 0083 · UDR : 0079
module UseCases
  module Classroom
    class RegisterStudent
      Registered = Data.define(:user, :classroom, :token)
      # La classe désignée et la voie qui y mène (Entities::Classroom::StudentArrivalChannel).
      Destination = Data.define(:classroom, :via)
      ROLE = "student".freeze
      STANDARD = "standard".freeze
      LINK = "link".freeze
      ALREADY_ENROLLED = { base: [ :already_enrolled ] }.freeze
      UNAVAILABLE = { classroom_public_id: [ :unavailable ] }.freeze

      # Un refus après la création du compte traverse la transaction pour l'annuler, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("inscription annulée : #{result.code}")
        end
      end

      def initialize(classrooms:, schools:, taxonomy:, registrations:, memberships:, sessions:, policy:, transaction:,
                     digest_key:, clock:)
        @classrooms = classrooms
        @schools = schools
        @taxonomy = taxonomy
        @registrations = registrations
        @memberships = memberships
        @sessions = sessions
        @policy = policy
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Classroom::StudentRegistrationInput.
      # → success(Registered) | :invalid (formulaire, classe hors liste) | :forbidden (déjà connecté, ou raison en
      #   errors[:base]) | :conflict (numéro pris, écriture refusée)
      def call(actor:, dto:, ip:, user_agent:)
        # Inscription publique : un élève connecté change de classe ailleurs (JoinAsStudent), les autres rôles n'ont rien ici.
        return Shared::Result.failure(:forbidden, errors: actor.student? ? ALREADY_ENROLLED : {}) if actor
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call { register(dto, ip, user_agent) }
      rescue Aborted => e
        e.result
      end

      private

      # Le verrou de la classe sérialise les adhésions : l'effectif lu reste juste jusqu'au commit (ADR-0041).
      def register(dto, ip, user_agent)
        destination = linked(dto.link_token) || chosen(dto)
        return destination if destination.is_a?(Shared::Result)

        # Un compte qui vient de naître n'a jamais été retiré d'une classe.
        allowed = @policy.call(actor: nil, classroom: destination.classroom, via_link: destination.via == LINK, removed: false)
        return allowed if allowed.failure?

        created = @registrations.create_student(user: user_from(dto), pin: dto.pin)
        return created if created.failure?

        enroll(created.value, destination, ip, user_agent)
      end

      # Résolu de nouveau à l'envoi (ADR-0083 §4.1) : un lien valide l'emporte sur la classe envoyée. Inconnu, changé, d'une
      # classe archivée ou d'un établissement qui n'est pas actif, il retombe sans rien dire sur la voie standard.
      def linked(token)
        classroom = token && @classrooms.lock_by_link_token(token:)
        Destination.new(classroom:, via: LINK) if classroom&.active? && school_of(classroom).active?
      end

      # La classe doit être de celles que la cascade propose (ADR-0083 §4.2), sinon la même erreur sous le champ.
      def chosen(dto)
        return Shared::Result.failure(:invalid, errors: { classroom_public_id: [ :blank ] }) if dto.classroom_public_id.nil?

        classroom = @classrooms.lock_by_public_id(public_id: dto.classroom_public_id)
        return Shared::Result.failure(:invalid, errors: UNAVAILABLE) unless listed?(classroom, dto)

        Destination.new(classroom:, via: STANDARD)
      end

      # Active, de l'année en cours, du niveau et de l'établissement envoyés, établissement actif.
      def listed?(classroom, dto)
        return false unless classroom&.active? && classroom.school_year == Entities::Classroom::SchoolYear.current(@clock.now.to_date)

        school = school_of(classroom)
        level = dto.level_slug && @taxonomy.find_level(slug: dto.level_slug)
        school.active? && school.public_id == dto.school_public_id && level&.id == classroom.level_id
      end

      # Une classe a toujours son établissement (clé étrangère, NOT NULL).
      def school_of(classroom) = @schools.find_by_id(id: classroom.school_id)

      def enroll(user, destination, ip, user_agent)
        now = @clock.now
        added = @memberships.add_primary(classroom_id: destination.classroom.id, student_id: user.id, via: destination.via, at: now)
        raise Aborted, added if added.failure?

        Shared::Result.success(Registered.new(user:, classroom: destination.classroom, token: open_session(user, ip, user_agent, now)))
      end

      def user_from(dto)
        Entities::Identity::User.new(last_name: dto.last_name, first_name: dto.first_name, contact: dto.contact,
                                     gender: dto.gender, role: ROLE)
      end

      def open_session(user, ip, user_agent, now)
        token = Entities::Identity::SecretDigest.generate_token
        @sessions.create(user_id: user.id, token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                         ip:, user_agent:, at: now)
        token
      end
    end
  end
end
