# 🧠 DOMAINE · UseCases::Classroom::RegisterStudent
# Rôle : un visiteur crée son compte élève (rôle imposé) et entre tout de suite dans la classe choisie ou celle de son lien, en une transaction
# ADR  : 0026, 0028, 0040, 0041, 0050, 0085 · UDR : 0081
module UseCases
  module Classroom
    class RegisterStudent
      Registered = Data.define(:user, :classroom, :token)
      ROLE = "student".freeze
      ALREADY_ENROLLED = { base: [ :already_enrolled ] }.freeze

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
        @designation = ClassroomDesignation.new(classrooms:, schools:, taxonomy:, clock:)
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

      # Le verrou de la classe sérialise les adhésions : l'effectif lu reste juste jusqu'au commit (ADR-0041). Résolu de
      # nouveau à l'envoi (ADR-0085 §4.1), un lien valide l'emporte sur la classe envoyée ; inconnu, changé, d'une classe
      # archivée ou d'un établissement qui n'est pas actif, il retombe sans rien dire sur la voie standard.
      def register(dto, ip, user_agent)
        destination = @designation.linked(dto.link_token) || @designation.chosen(dto)
        return destination if destination.is_a?(Shared::Result)

        # Un compte qui vient de naître n'a jamais été retiré d'une classe.
        allowed = @policy.call(actor: nil, classroom: destination.classroom, via_link: destination.via == ClassroomDesignation::LINK, removed: false)
        return allowed if allowed.failure?

        created = @registrations.create_student(user: user_from(dto), pin: dto.pin)
        return created if created.failure?

        enroll(created.value, destination, ip, user_agent)
      end

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
