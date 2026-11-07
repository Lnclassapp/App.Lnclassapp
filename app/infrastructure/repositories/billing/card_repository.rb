# 🔌 INFRA · Repositories::Billing::CardRepository
# Rôle : traduit Orm::Billing::ActivationCard et CardBatch en entités ; tire les codes, verrouille la carte à activer ou annuler
# ADR  : cartes-activation (contexte billing, §4.2 et §4.3), 0029
module Repositories
  module Billing
    class CardRepository
      include Ports::Billing::CardRepositoryPort

      def create_batch(relay_point_id:, quantity:, unit_price_xof:, valid_until:, created_by_id:, at:)
        Orm::Billing::CardBatch.transaction(requires_new: true) do
          batch = Orm::Billing::CardBatch.create!(relay_point_id:, quantity:, unit_price_xof:, valid_until:, created_by_id:, created_at: at)
          cards = Array.new(quantity) { issue_card(batch) }
          map_batch(batch, cards)
        end
      end

      def cards_of_batch(batch_public_id:)
        Orm::Billing::ActivationCard.joins(:batch).where(batch: { public_id: batch_public_id }).order(:serial).map { map_card(it) }
      end

      def lock_by_code(code:)
        record = Orm::Billing::ActivationCard.lock.find_by(code:)
        record && map_card(record)
      end

      def activate(card_id:, student_id:, school_id:, at:)
        record = Orm::Billing::ActivationCard.lock.find(card_id)
        refusal = activation_refusal(record)
        return refusal if refusal

        Orm::Billing::ActivationCard.transaction(requires_new: true) do
          record.update!(state: "activated", student_id:, school_id:, activated_at: at)
        end
        ::Shared::Result.success(map_card(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { base: [ :already_subscribed ] })
      end

      def subscribed_until(student_id:)
        Orm::Billing::ActivationCard.where(student_id:, state: "activated").maximum(:valid_until)
      end

      def find_by_serial(serial:)
        record = Orm::Billing::ActivationCard.find_by(serial:)
        record && map_card(record)
      end

      def cancel(card_id:, by_id:, reason:, at:)
        record = Orm::Billing::ActivationCard.lock.find(card_id)
        return ::Shared::Result.failure(:conflict, errors: { base: [ :card_activated ] }) if record.state == "activated"
        return ::Shared::Result.failure(:conflict, errors: { base: [ :card_cancelled ] }) if record.state == "cancelled"

        record.update!(state: "cancelled", cancelled_by_id: by_id, cancel_reason: reason, cancelled_at: at)
        ::Shared::Result.success(map_card(record))
      end

      private

      # Un code déjà pris (index unique du chiffré) : on en retire un autre, dans un savepoint pour ne pas casser le lot.
      def issue_card(batch)
        loop do
          card = Orm::Billing::ActivationCard.new(batch:, relay_point_id: batch.relay_point_id, price_xof: batch.unit_price_xof,
                                                  valid_until: batch.valid_until, code: Entities::Billing::ActivationCode.generate)
          Orm::Billing::ActivationCard.transaction(requires_new: true) { card.save! }
          return card
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end

      def activation_refusal(record)
        case record.state
        when "activated" then ::Shared::Result.failure(:conflict, errors: { base: [ :card_used ] })
        when "cancelled" then ::Shared::Result.failure(:invalid, errors: { base: [ :card_cancelled ] })
        end
      end

      def map_batch(record, cards)
        Entities::Billing::CardBatch.new(id: record.id, public_id: record.public_id, relay_point_id: record.relay_point_id,
                                         quantity: record.quantity, unit_price_xof: record.unit_price_xof, valid_until: record.valid_until,
                                         created_by_id: record.created_by_id, created_at: record.created_at,
                                         cards: cards.map { map_card(it) })
      end

      def map_card(record)
        Entities::Billing::ActivationCard.new(
          id: record.id, public_id: record.public_id, batch_id: record.batch_id, relay_point_id: record.relay_point_id,
          serial: record.serial, code: record.code, price_xof: record.price_xof, valid_until: record.valid_until, state: record.state,
          student_id: record.student_id, school_id: record.school_id, activated_at: record.activated_at,
          cancelled_at: record.cancelled_at, cancelled_by_id: record.cancelled_by_id, cancel_reason: record.cancel_reason
        )
      end
    end
  end
end
