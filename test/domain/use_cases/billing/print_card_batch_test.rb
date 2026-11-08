require "test_helper"

module UseCases
  module Billing
    class PrintCardBatchTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 13, 9)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      STUDENT = Entities::Identity::Actor.new(user_id: 9, role: :student)

      class FakeCards
        include Ports::Billing::CardRepositoryPort

        def initialize(cards) = @cards = cards

        def cards_of_batch(batch_public_id:) = @cards
      end

      def print(actor: TEAM, cards: [ Entities::Billing::ActivationCard.new(id: 1, batch_id: 4, relay_point_id: 3, serial: 21, code: "K7QHM3XP9TRA") ])
        @audit = FakeAuditLog.new
        PrintCardBatch.new(cards: FakeCards.new(cards), audit_log: @audit, policy: Policies::Billing::ManageBillingPolicy.new, clock: Clock.new(NOW))
                      .call(actor:, batch_public_id: "Batch000001")
      end

      test "rend les cartes et écrit l'audit de l'impression, sans aucun code" do
        result = print

        assert_equal [ 21 ], result.value.map(&:serial)
        event = @audit.events.sole
        assert_equal [ "billing.card_batch_printed", 7, "CardBatch", 4, NOW ], event.values_at(:action, :actor_id, :subject_type, :subject_id, :at)
        assert_equal({ batch_public_id: "Batch000001", relay_point_id: 3, quantity: 1 }, event[:metadata])
        assert_not_includes event.to_s, "K7QHM3XP9TRA"
      end

      test "refuse un non-équipe sans audit" do
        result = print(actor: STUDENT)

        assert_equal :forbidden, result.code
        assert_empty @audit.events
      end

      test "un lot sans carte est introuvable, sans audit" do
        result = print(cards: [])

        assert_equal :not_found, result.code
        assert_empty @audit.events
      end
    end
  end
end
