require "test_helper"

module UseCases
  module Billing
    class CancelCardTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 13, 9)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")

      class FakeCards
        include Ports::Billing::CardRepositoryPort

        attr_reader :cancelled

        def initialize(card)
          @card = card
          @cancelled = []
        end

        def find_by_serial(serial:) = (@card if @card&.serial == serial)

        def cancel(card_id:, by_id:, reason:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :card_activated ] }) if @card.activated?

          @cancelled << { card_id:, by_id:, reason:, at: }
          Shared::Result.success(@card.with(state: "cancelled", cancel_reason: reason))
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def cancel(state: "issued", serial: 21, reason: "perdue", actor: TEAM)
        card = Entities::Billing::ActivationCard.new(id: 5, serial: 21, state:, relay_point_id: 3)
        @cards = FakeCards.new(card)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        CancelCard.new(cards: @cards, audit_log: @audit, transaction: @transaction, policy: Policies::Billing::ManageBillingPolicy.new,
                       clock: Clock.new(NOW)).call(actor:, serial:, reason:)
      end

      test "l'équipe annule une carte remise : motif gardé, audit avec auteur et date, dans une transaction" do
        result = cancel

        assert result.success?
        assert_equal [ { card_id: 5, by_id: 7, reason: "perdue", at: NOW } ], @cards.cancelled
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "billing.card_cancelled", actor_id: 7, at: NOW, subject_type: "ActivationCard", subject_id: 5,
                         metadata: { serial: 21, reason: "perdue", relay_point_id: 3 } } ], @audit.events
      end

      test "une carte activée ne s'annule pas" do
        result = cancel(state: "activated")

        assert_equal :conflict, result.code
        assert_equal [ :card_activated ], result.errors[:base]
        assert_nil @audit.events
      end

      test "un motif vide ou trop long est invalide" do
        assert_equal [ :blank ], cancel(reason: " ").errors[:reason]
        assert_equal [ :too_long ], cancel(reason: "x" * 201).errors[:reason]
        assert_empty @cards.cancelled
      end

      test "un numéro inconnu est introuvable" do
        assert_equal :not_found, cancel(serial: 99).code
      end

      test "refuse tout autre rôle et le visiteur" do
        [ nil, Entities::Identity::Actor.new(user_id: 4, role: :student), Entities::Identity::Actor.new(user_id: 3, role: :teacher) ].each do |actor|
          assert_equal :forbidden, cancel(actor:).code
          assert_empty @cards.cancelled
        end
      end
    end
  end
end
