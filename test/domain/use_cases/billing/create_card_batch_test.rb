require "test_helper"

module UseCases
  module Billing
    class CreateCardBatchTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 8, 9)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      TEACHER = Entities::Identity::Actor.new(user_id: 8, role: :teacher)

      class FakeRelayPoints
        include Ports::Billing::RelayPointRepositoryPort

        def initialize(active: true) = @point = Entities::Billing::RelayPoint.new(id: 3, public_id: "RelayPoint0001", name: "Awa", active:)

        def find(public_id:) = (@point if public_id == "RelayPoint0001")
      end

      class FakeCards
        include Ports::Billing::CardRepositoryPort

        attr_reader :created

        def create_batch(**args)
          @created = args
          Entities::Billing::CardBatch.new(id: 5, public_id: "Batch00000001", relay_point_id: args[:relay_point_id], quantity: args[:quantity],
                                           unit_price_xof: args[:unit_price_xof], valid_until: args[:valid_until])
        end
      end

      def create(attributes, actor: TEAM, public_id: "RelayPoint0001", active: true)
        @cards = FakeCards.new
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        CreateCardBatch.new(cards: @cards, relay_points: FakeRelayPoints.new(active:), audit_log: @audit, transaction: @transaction,
                            policy: Policies::Billing::ManageBillingPolicy.new, clock: Clock.new(NOW))
                       .call(actor:, relay_point_public_id: public_id, dto: Dtos::Billing::CardBatchInput.new(attributes))
      end

      test "l'équipe crée un lot de 20 cartes à 10 000 F valables jusqu'à la fin de l'offre, journalisé" do
        result = create({ quantity: "20", unit_price_xof: "10000" })

        assert result.success?
        assert_equal({ relay_point_id: 3, quantity: 20, unit_price_xof: 10_000, valid_until: Entities::Billing::Offer::VALID_UNTIL,
                       created_by_id: 7, at: NOW }, @cards.created)
        assert_equal [ "billing.card_batch_created", 7, "CardBatch", 5 ], @audit.events.sole.values_at(:action, :actor_id, :subject_type, :subject_id)
        assert_equal({ relay_point_id: 3, quantity: 20, unit_price_xof: 10_000 }, @audit.events.sole[:metadata])
      end

      test "un lot offert a un prix de 0" do
        assert_equal 0, create({ quantity: 5, unit_price_xof: 0 }).value.unit_price_xof
      end

      test "la quantité va de 1 à 200 et le prix est 10 000 F ou offert" do
        [ { quantity: 0, unit_price_xof: 10_000 }, { quantity: 201, unit_price_xof: 10_000 }, { quantity: 10, unit_price_xof: 500 } ].each do |attributes|
          result = create(attributes)

          assert_equal :invalid, result.code
          assert_nil @cards.created
        end
      end

      test "un point relais inconnu rend :not_found, un point relais désactivé est refusé" do
        assert_equal :not_found, create({ quantity: 5, unit_price_xof: 0 }, public_id: "Inconnu").code
        assert_equal [ :inactive ], create({ quantity: 5, unit_price_xof: 0 }, active: false).errors[:base]
        assert_nil @cards.created
      end

      test "un enseignant est refusé" do
        assert_equal :forbidden, create({ quantity: 5, unit_price_xof: 0 }, actor: TEACHER).code
        assert_nil @cards.created
      end
    end
  end
end
