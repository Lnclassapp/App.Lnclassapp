# 🧠 DOMAINE · UseCases::Classroom::ChangeClassroom
# Rôle : l'élève à classe active en change lui-même, après confirmation : l'ancienne adhésion est close sans retrait, la nouvelle ouverte, le départ tracé
# ADR  : 0028, 0040, 0041, 0085, 0088, 0095 · UDR : 0102
module UseCases
  module Classroom
    class ChangeClassroom
      ACTION = "classroom.student_moved".freeze
      NO_ACTIVE_CLASSROOM = { base: [ :no_active_classroom ] }.freeze
      SAME_CLASSROOM = { base: [ :same_classroom ] }.freeze

      # L'échec de la nouvelle adhésion traverse la transaction pour rouvrir l'ancienne, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("changement annulé : #{result.code}")
        end
      end

      def initialize(classrooms:, schools:, taxonomy:, memberships:, audit_log:, policy:, transaction:, clock:)
        @designation = ClassroomDesignation.new(classrooms:, schools:, taxonomy:, clock:)
        @memberships = memberships
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Classroom::StudentRegistrationInput ; link_token (voie « link »), sinon la cascade (voie « standard »).
      # → success(Entities::Classroom::Classroom, la classe d'arrivée) | :forbidden (rôle, no_active_classroom, raison de
      #   JoinPolicy, classroom_archived) | :invalid (same_classroom, classe hors cascade) | :not_found (lien mort) | :conflict
      def call(actor:, dto:)
        return Shared::Result.failure(:forbidden) unless actor&.student?

        @transaction.call { change(actor, dto) }
      rescue Aborted => e
        e.result
      end

      private

      # La classe d'arrivée est verrouillée avant de lire la classe actuelle : un second envoi simultané vers la même
      # classe attend le premier, puis lit la nouvelle classe et tombe sur same_classroom (rien de plus n'est écrit).
      def change(actor, dto)
        destination = @designation.designate(dto)
        return destination if destination.is_a?(Shared::Result)

        current = @memberships.primary_for(student_id: actor.user_id)
        return Shared::Result.failure(:forbidden, errors: NO_ACTIVE_CLASSROOM) unless current&.classroom_active?
        return Shared::Result.failure(:invalid, errors: SAME_CLASSROOM) if current.classroom_id == destination.classroom.id

        allowed = allowed(actor, destination)
        return allowed if allowed.failure?

        move(actor.user_id, current, destination)
      end

      # ADR-0085 §4.3 : le retrait ne ferme que la voie standard ; le lien le lève.
      def allowed(actor, destination)
        classroom = destination.classroom
        via_link = destination.via == ClassroomDesignation::LINK
        removed = !via_link && @memberships.removed_from?(classroom_id: classroom.id, student_id: actor.user_id)
        @policy.call(actor:, classroom:, via_link:, removed:)
      end

      # ADR-0095 §4.2 : un départ, pas un retrait (left_at seul) ; la trace distingue le départ volontaire d'un archivage.
      def move(student_id, current, destination)
        now = @clock.now
        classroom = destination.classroom
        @memberships.leave_primary(student_id:, at: now)
        added = @memberships.add_primary(classroom_id: classroom.id, student_id:, via: destination.via, at: now)
        raise Aborted, added if added.failure?

        @audit_log.record(action: ACTION, actor_id: student_id, at: now, subject_type: "User", subject_id: student_id,
                          metadata: { from_classroom_id: current.classroom_id, to_classroom_id: classroom.id,
                                      to_school_id: classroom.school_id, via: destination.via })
        Shared::Result.success(classroom)
      end
    end
  end
end
