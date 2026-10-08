# 🧠 DOMAINE · UseCases::Classroom::JoinAsStudent
# Rôle : un élève connecté sans classe active (classe archivée, ou retiré) entre dans la classe choisie, celle d'un lien, ou d'un ancien code
# ADR  : 0026, 0028, 0040, 0041, 0085 · UDR : 0009, 0081
module UseCases
  module Classroom
    class JoinAsStudent
      # La classe désignée et la voie qui y mène (Entities::Classroom::StudentArrivalChannel ; « code » jusqu'au Lot F).
      Destination = Data.define(:classroom, :via)
      STANDARD = "standard".freeze
      LINK = "link".freeze
      CODE = "code".freeze
      ALREADY_ENROLLED = { base: [ :already_enrolled ] }.freeze
      BLANK = { classroom_public_id: [ :blank ] }.freeze
      UNAVAILABLE = { classroom_public_id: [ :unavailable ] }.freeze

      # L'échec de la nouvelle adhésion traverse la transaction pour rouvrir l'ancienne, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("adhésion annulée : #{result.code}")
        end
      end

      def initialize(classrooms:, schools:, taxonomy:, memberships:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @schools = schools
        @taxonomy = taxonomy
        @memberships = memberships
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Classroom::StudentRegistrationInput, dont seuls les champs de la classe comptent : link_token (voie
      # « link »), sinon school_public_id, level_slug et classroom_public_id (voie « standard »). code : l'ancien chemin
      # /c/<code>, à la place du dto, jusqu'au Lot F.
      # → success(Entities::Classroom::Classroom) | :forbidden (visiteur, rôle, ou raison en errors[:base], déjà inscrit
      #   compris) | :not_found (lien ou code qui ne mène plus à une classe ouverte) | :invalid (classe hors de la cascade)
      #   | :conflict (écriture refusée)
      def call(actor:, dto: nil, code: nil)
        # Un visiteur s'inscrit par RegisterStudent ; les autres rôles n'ont pas de classe principale.
        return Shared::Result.failure(:forbidden) unless actor&.student?

        @transaction.call { join(actor, dto, code) }
      rescue Aborted => e
        e.result
      end

      private

      # ADR-0040 : une seule classe principale active. L'élève qui en a une le sait d'abord, quelle que soit la classe visée.
      def join(actor, dto, code)
        current = @memberships.primary_for(student_id: actor.user_id)
        return Shared::Result.failure(:forbidden, errors: ALREADY_ENROLLED) if current&.classroom_active?

        destination = code ? coded(code) : designated(dto)
        return destination if destination.is_a?(Shared::Result)

        allowed = allowed(actor, destination, code)
        return allowed if allowed.failure?

        move(actor.user_id, current, destination)
      end

      # ADR-0085 §4.3 : le retrait ne ferme que la voie standard (et l'ancien code) ; le lien le lève.
      def allowed(actor, destination, code)
        classroom = destination.classroom
        via_link = destination.via == LINK
        removed = !via_link && @memberships.removed_from?(classroom_id: classroom.id, student_id: actor.user_id)
        @policy.call(actor:, classroom:, via_link:, removed:, code:)
      end

      def designated(dto) = dto.link_token ? linked(dto.link_token) : chosen(dto)

      # ADR-0085 §4.1 : le lien n'ouvre qu'une classe active d'un établissement actif ; sinon il ne mène nulle part.
      def linked(token)
        classroom = @classrooms.lock_by_link_token(token:)
        return Shared::Result.failure(:not_found) unless classroom&.active? && school_of(classroom).active?

        Destination.new(classroom:, via: LINK)
      end

      # La classe doit être de celles que la cascade propose (ADR-0085 §4.2), sinon la même erreur sous le champ.
      def chosen(dto)
        return Shared::Result.failure(:invalid, errors: BLANK) if dto.classroom_public_id.nil?

        classroom = @classrooms.lock_by_public_id(public_id: dto.classroom_public_id)
        return Shared::Result.failure(:invalid, errors: UNAVAILABLE) unless listed?(classroom, dto)

        Destination.new(classroom:, via: STANDARD)
      end

      def coded(code)
        classroom = @classrooms.lock_by_join_code(join_code: Entities::Classroom::JoinCode.normalize(code))
        classroom ? Destination.new(classroom:, via: CODE) : Shared::Result.failure(:not_found)
      end

      # Active, de l'année en cours, du niveau et de l'établissement envoyés, établissement actif (règle de RegisterStudent).
      def listed?(classroom, dto)
        return false unless classroom&.active? && classroom.school_year == Entities::Classroom::SchoolYear.current(@clock.now.to_date)

        school = school_of(classroom)
        level = dto.level_slug && @taxonomy.find_level(slug: dto.level_slug)
        school.active? && school.public_id == dto.school_public_id && level&.id == classroom.level_id
      end

      # Une classe a toujours son établissement (clé étrangère, NOT NULL).
      def school_of(classroom) = @schools.find_by_id(id: classroom.school_id)

      # IL-17 : l'adhésion à la classe archivée est close dans la même transaction que la nouvelle.
      def move(student_id, current, destination)
        now = @clock.now
        @memberships.leave_primary(student_id:, at: now) if current
        added = @memberships.add_primary(classroom_id: destination.classroom.id, student_id:, via: destination.via, at: now)
        raise Aborted, added if added.failure?

        Shared::Result.success(destination.classroom)
      end
    end
  end
end
