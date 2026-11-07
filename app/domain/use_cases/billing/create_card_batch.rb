# 🧠 DOMAINE · UseCases::Billing::CreateCardBatch
# Rôle : l'équipe crée un lot de cartes pour un point relais actif, au prix de l'offre ou offert, valable jusqu'à la fin de l'offre
# ADR  : cartes-activation (contexte billing, §4.1, §4.8 et §4.10)
module UseCases
  module Billing
    class CreateCardBatch
      def initialize(cards:, relay_points:, audit_log:, transaction:, policy:, clock:)
        @cards = cards
        @relay_points = relay_points
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Billing::CardBatchInput. → Result(Entities::Billing::CardBatch avec ses cartes)
      # | :forbidden | :invalid | :not_found (point relais inconnu) | :invalid base: [:inactive] (point relais désactivé)
      def call(actor:, relay_point_public_id:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        relay_point = @relay_points.find(public_id: relay_point_public_id)
        return Shared::Result.failure(:not_found) if relay_point.nil?
        return Shared::Result.failure(:invalid, errors: { base: [ :inactive ] }) unless relay_point.active

        @transaction.call { store(actor, relay_point, dto) }
      end

      private

      def store(actor, relay_point, dto)
        batch = @cards.create_batch(relay_point_id: relay_point.id, quantity: dto.quantity, unit_price_xof: dto.unit_price_xof,
                                    valid_until: Entities::Billing::Offer::VALID_UNTIL, created_by_id: actor.user_id, at: @clock.now)
        @audit_log.record(action: "billing.card_batch_created", actor_id: actor.user_id, at: @clock.now, subject_type: "CardBatch",
                          subject_id: batch.id,
                          metadata: { relay_point_id: relay_point.id, quantity: dto.quantity, unit_price_xof: dto.unit_price_xof })
        Shared::Result.success(batch)
      end
    end
  end
end
