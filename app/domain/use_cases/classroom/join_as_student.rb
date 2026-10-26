# 🧠 DOMAINE · UseCases::Classroom::JoinAsStudent
# Rôle : un élève connecté sans classe active (classe archivée, ou retiré) entre dans la classe choisie, dans celle de son code ou dans celle d'un lien
# ADR  : 0026, 0028, 0040, 0041, 0085, 0088, 0109 · UDR : 0009, 0081
module UseCases
  module Classroom
    class JoinAsStudent
      ALREADY_ENROLLED = { base: [ :already_enrolled ] }.freeze

      # L'échec de la nouvelle adhésion traverse la transaction pour rouvrir l'ancienne, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("adhésion annulée : #{result.code}")
        end
      end

      def initialize(classrooms:, schools:, taxonomy:, memberships:, policy:, transaction:, clock:)
        @designation = ClassroomDesignation.new(classrooms:, schools:, taxonomy:, clock:)
        @memberships = memberships
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Classroom::StudentRegistrationInput, dont seuls les champs de la classe comptent : link_token (voie
      # « link »), sinon join_code (voie « code »), sinon school_public_id, level_slug et classroom_public_id (voie « standard »).
      # → success(Entities::Classroom::Classroom) | :forbidden (visiteur, rôle, ou raison en errors[:base], déjà inscrit
      #   compris) | :not_found (lien qui ne mène plus à une classe ouverte) | :invalid (classe hors de la cascade)
      #   | :conflict (écriture refusée)
      def call(actor:, dto:)
        # Un visiteur s'inscrit par RegisterStudent ; les autres rôles n'ont pas de classe principale.
        return Shared::Result.failure(:forbidden) unless actor&.student?

        @transaction.call { join(actor, dto) }
      rescue Aborted => e
        e.result
      end

      private

      # ADR-0040 : une seule classe principale active. L'élève qui en a une le sait d'abord, quelle que soit la classe visée.
      def join(actor, dto)
        current = @memberships.primary_for(student_id: actor.user_id)
        return Shared::Result.failure(:forbidden, errors: ALREADY_ENROLLED) if current&.classroom_active?

        destination = @designation.designate(dto)
        return destination if destination.is_a?(Shared::Result)

        allowed = allowed(actor, destination)
        return allowed if allowed.failure?

        move(actor.user_id, current, destination)
      end

      # ADR-0085 §4.3 : le retrait ferme la voie standard et celle du code ; seul le lien le lève : retaper le code ne contourne pas un retrait.
      def allowed(actor, destination)
        classroom = destination.classroom
        via_link = destination.via == ClassroomDesignation::LINK
        removed = !via_link && @memberships.removed_from?(classroom_id: classroom.id, student_id: actor.user_id)
        @policy.call(actor:, classroom:, via_link:, removed:)
      end

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
