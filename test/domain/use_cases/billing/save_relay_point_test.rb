require "test_helper"

module UseCases
  module Billing
    class SaveRelayPointTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 8, 9)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      STUDENT = Entities::Identity::Actor.new(user_id: 9, role: :student)

      class FakeRelayPoints
        include Ports::Billing::RelayPointRepositoryPort

        attr_reader :saved

        def initialize(existing: nil) = @existing = existing

        def find(public_id:) = (@existing if @existing&.public_id == public_id)

        def save(relay_point:, school_ids:)
          @saved = [ relay_point, school_ids ]
          Shared::Result.success(relay_point.with(id: relay_point.id || 3, public_id: relay_point.public_id || "RelayPoint0001", school_ids:))
        end
      end

      def save(dto_attributes, actor: TEAM, public_id: nil, existing: nil)
        @relay_points = FakeRelayPoints.new(existing:)
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        SaveRelayPoint.new(relay_points: @relay_points, audit_log: @audit, transaction: @transaction,
                           policy: Policies::Billing::ManageBillingPolicy.new, clock: Clock.new(NOW))
                      .call(actor:, dto: Dtos::Billing::RelayPointInput.new(dto_attributes), public_id:)
      end

      def valid_attributes = { name: "Boutique Awa", location: "Près du marché", phone: "0700000000", school_ids: [ "4", "5", "4" ] }

      test "l'équipe crée un point relais rattaché à deux écoles, journalisé" do
        result = save(valid_attributes)

        assert result.success?
        assert_equal [ 4, 5 ], @relay_points.saved.last
        assert_equal "07 00 00 00 00", @relay_points.saved.first.phone
        assert_equal 1, @transaction.calls
        event = @audit.events.sole
        assert_equal [ "billing.relay_point_saved", 7, NOW, "RelayPoint", 3 ], event.values_at(:action, :actor_id, :at, :subject_type, :subject_id)
        assert_equal "created", event[:metadata][:change]
        assert_equal [ 4, 5 ], event[:metadata][:school_ids]
      end

      test "une modification garde l'identité du point relais et le dit au journal" do
        existing = Entities::Billing::RelayPoint.new(id: 3, public_id: "RelayPoint0001", name: "Ancien", location: "x", phone: "0700000000")

        result = save(valid_attributes.merge(active: "0"), public_id: "RelayPoint0001", existing:)

        assert result.success?
        assert_equal [ 3, false ], @relay_points.saved.first.then { [ it.id, it.active ] }
        assert_equal "updated", @audit.events.sole[:metadata][:change]
      end

      test "un point relais inconnu rend :not_found" do
        result = save(valid_attributes, public_id: "Inconnu", existing: nil)

        assert_equal :not_found, result.code
        assert_empty @audit.events
      end

      test "nom, lieu et téléphone sont obligatoires, le téléphone a dix chiffres" do
        result = save({ name: " ", location: "", phone: "123", school_ids: [] })

        assert_equal :invalid, result.code
        assert_equal %i[name location phone], result.errors.keys
        assert_nil @relay_points.saved
        assert_empty @audit.events
      end

      test "un élève est refusé sans rien écrire" do
        result = save(valid_attributes, actor: STUDENT)

        assert_equal :forbidden, result.code
        assert_nil @relay_points.saved
      end

      test "l'audit garde les écoles rendues par le dépôt, pas la saisie" do
        relay_points = FakeRelayPoints.new
        relay_points.define_singleton_method(:save) do |relay_point:, school_ids:|
          Shared::Result.success(relay_point.with(id: 3, public_id: "RelayPoint0001", school_ids: [ 4 ]))
        end
        audit = FakeAuditLog.new
        SaveRelayPoint.new(relay_points:, audit_log: audit, transaction: FakeTransaction.new,
                           policy: Policies::Billing::ManageBillingPolicy.new, clock: Clock.new(NOW))
                      .call(actor: TEAM, dto: Dtos::Billing::RelayPointInput.new(valid_attributes))

        assert_equal [ 4 ], audit.events.sole[:metadata][:school_ids]
      end

      test "un échec du dépôt est rendu tel quel, sans audit" do
        relay_points = FakeRelayPoints.new
        relay_points.define_singleton_method(:save) { |**| Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] }) }
        audit = FakeAuditLog.new
        result = SaveRelayPoint.new(relay_points:, audit_log: audit, transaction: FakeTransaction.new,
                                    policy: Policies::Billing::ManageBillingPolicy.new, clock: Clock.new(NOW))
                               .call(actor: TEAM, dto: Dtos::Billing::RelayPointInput.new(valid_attributes))

        assert_equal [ :conflict, { base: [ :write_failed ] } ], [ result.code, result.errors ]
        assert_empty audit.events
      end
    end
  end
end
