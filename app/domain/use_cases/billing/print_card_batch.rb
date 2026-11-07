# 🧠 DOMAINE · UseCases::Billing::PrintCardBatch
# Rôle : l'équipe affiche la planche d'un lot ; chaque affichage est journalisé (qui, quel lot, quel point relais), jamais un code
# ADR  : 0126 (contexte billing, §4.2 et §4.10), 0031
module UseCases
  module Billing
    class PrintCardBatch
      def initialize(cards:, audit_log:, policy:, clock:)
        @cards = cards
        @audit_log = audit_log
        @policy = policy
        @clock = clock
      end

      # → Result([Entities::Billing::ActivationCard], par numéro) | :forbidden | :not_found (lot inconnu ou sans carte)
      def call(actor:, batch_public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        cards = @cards.cards_of_batch(batch_public_id:)
        return Shared::Result.failure(:not_found) if cards.empty?

        @audit_log.record(action: "billing.card_batch_printed", actor_id: actor.user_id, at: @clock.now, subject_type: "CardBatch",
                          subject_id: cards.first.batch_id,
                          metadata: { batch_public_id:, relay_point_id: cards.first.relay_point_id, quantity: cards.size })
        Shared::Result.success(cards)
      end
    end
  end
end
