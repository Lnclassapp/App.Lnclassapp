# 🧠 DOMAINE · UseCases::Assessment::PublishExercise
# Rôle : l'équipe publie (ou republie) un exercice qui a au moins une question bien construite, sous une fiche publiée
# ADR  : 0026, 0028, 0035, 0054 · UDR : 0017
module UseCases
  module Assessment
    class PublishExercise
      def initialize(exercises:, audit_log:, transaction:, policy:, clock:)
        @exercises = exercises
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Exercise) | :forbidden | :not_found
      #   | :conflict, base: [:transition_not_allowed | :parent_not_published | :not_publishable]
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        exercise = @exercises.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if exercise.nil?

        # parents_published : la fiche essentielle et son cours, toute la chaîne que l'élève doit pouvoir lire.
        transition = Entities::Shared::ContentStatus.transition(from: exercise.status, to: "published",
                                                                 parent_published: exercise.parents_published)
        return transition if transition.failure?
        return Shared::Result.failure(:conflict, errors: { base: [ :not_publishable ] }) unless exercise.publishable?

        @transaction.call { publish(actor, exercise) }
      end

      private

      def publish(actor, exercise)
        now = @clock.now
        @exercises.transition(id: exercise.id, to: "published", at: now)
        @audit_log.record(action: "content.published", actor_id: actor.user_id, at: now, subject_type: "Exercise",
                          subject_id: exercise.id, metadata: { public_id: exercise.public_id })
        Shared::Result.success(@exercises.find_by_public_id(public_id: exercise.public_id))
      end
    end
  end
end
