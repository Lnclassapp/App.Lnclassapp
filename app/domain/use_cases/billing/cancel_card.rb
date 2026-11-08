# 🧠 DOMAINE · UseCases::Billing::CancelCard
# Rôle : l'équipe annule une carte remise et non activée, avec un motif ; l'auteur, la date et le motif restent dans l'audit
# ADR  : 0126 (contexte billing, §4.3 et §4.7)
module UseCases
  module Billing
    class CancelCard
      REASON_MAX = 200

      def initialize(cards:, audit_log:, transaction:, policy:, clock:)
        @cards = cards
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Entities::Billing::ActivationCard) | :forbidden | :invalid (motif) | :not_found | :conflict (activée ou déjà annulée)
      def call(actor:, serial:, reason:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        reason = reason.to_s.squish
        return Shared::Result.failure(:invalid, errors: { reason: [ :blank ] }) if reason.empty?
        return Shared::Result.failure(:invalid, errors: { reason: [ :too_long ] }) if reason.length > REASON_MAX

        card = @cards.find_by_serial(serial:)
        return Shared::Result.failure(:not_found) if card.nil?

        @transaction.call { cancel(actor, card, reason) }
      end

      private

      def cancel(actor, card, reason)
        at = @clock.now
        cancelled = @cards.cancel(card_id: card.id, by_id: actor.user_id, reason:, at:)
        return cancelled if cancelled.failure?

        @audit_log.record(action: "billing.card_cancelled", actor_id: actor.user_id, at:, subject_type: "ActivationCard",
                          subject_id: card.id, metadata: { serial: card.serial, reason:, relay_point_id: card.relay_point_id })
        cancelled
      end
    end
  end
end
