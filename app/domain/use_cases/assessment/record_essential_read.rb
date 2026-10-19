# 🧠 DOMAINE · UseCases::Assessment::RecordEssentialRead
# Rôle : retient la fiche ouverte par un élève (Commencer / Reprendre / Revoir) ; personne d'autre ; une panne du stockage ne lève pas
# ADR  : 0026, 0028, 0036, 0090 (§4.1)
module UseCases
  module Assessment
    class RecordEssentialRead
      # policy : Policies::Catalog::ReadPublishedPolicy, la règle de lecture de la fiche (rejouée ici, ADR-0028).
      # reporter : répond à report(error, handled: true, context:) (Rails.error, injecté par le contrôleur).
      # recoverable : la ou les classes d'erreur du stockage avalées (ActiveRecord::ActiveRecordError, nommée par la
      # delivery : le domaine ne connaît pas ActiveRecord). Toute autre erreur est un bogue et remonte.
      def initialize(reads:, policy:, reporter:, recoverable:, clock:)
        @reads = reads
        @policy = policy
        @reporter = reporter
        @recoverable = Array(recoverable)
        @clock = clock
      end

      # essential : tout objet qui répond à id et readable_chain_published? (Entities::Catalog::Essential).
      # → Result(true : lecture retenue | false : acteur autre qu'un élève, ou panne signalée) | :not_found | :forbidden
      def call(actor:, essential:)
        allowed = @policy.call(actor:, content: essential)
        return allowed if allowed.failure?
        return Shared::Result.success(false) unless actor.student?

        Shared::Result.success(@reads.record(student_id: actor.user_id, essential_id: essential.id, at: @clock.now))
      rescue *@recoverable => error
        # La fiche s'affiche quand même (ADR-0090 §4.1) : la panne est signalée, la lecture n'est pas retenue.
        @reporter.report(error, handled: true, context: { essential_id: essential.id, student_id: actor.user_id })
        Shared::Result.success(false)
      end
    end
  end
end
