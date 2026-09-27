# 🧠 DOMAINE · UseCases::Assessment::ArchiveExercise
# Rôle : l'équipe archive un exercice publié ; rien n'est détruit, ni questions, ni sessions, ni tentatives, ni badges
# ADR  : 0026, 0028, 0035, 0036 · UDR : 0017
module UseCases
  module Assessment
    class ArchiveExercise
      def initialize(exercises:, audit_log:, transaction:, policy:, clock:)
        @exercises = exercises
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Exercise) | :forbidden | :not_found | :conflict, base: [:transition_not_allowed]
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        exercise = @exercises.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if exercise.nil?

        transition = Entities::Catalog::ContentStatus.transition(from: exercise.status, to: "archived",
                                                                 parent_published: exercise.parents_published)
        return transition if transition.failure?

        @transaction.call { archive(actor, exercise) }
      end

      private

      def archive(actor, exercise)
        now = @clock.now
        @exercises.transition(id: exercise.id, to: "archived", at: now)
        @audit_log.record(action: "content.archived", actor_id: actor.user_id, at: now, subject_type: "Exercise",
                          subject_id: exercise.id, metadata: { public_id: exercise.public_id })
        Shared::Result.success(@exercises.find_by_public_id(public_id: exercise.public_id))
      end
    end
  end
end
