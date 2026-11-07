require "test_helper"

module UseCases
  module Billing
    class RecordRemittanceTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 13, 9)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")

      class FakeRemittances
        include Ports::Billing::RemittanceRepositoryPort

        attr_reader :recorded

        def record(relay_point_id:, amount_xof:, received_at:, reference:, reason:, recorded_by_id:)
          remittance = Entities::Billing::Remittance.new(id: 11, relay_point_id:, amount_xof:, received_at:, reference:, reason:, recorded_by_id:)
          (@recorded ||= []) << remittance
          Shared::Result.success(remittance)
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def record(actor: TEAM, **attributes)
        @remittances = FakeRemittances.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        dto = Dtos::Billing::RemittanceInput.new({ relay_point_id: 3, amount_xof: "10000", reference: "WAVE-1" }.merge(attributes))
        RecordRemittance.new(remittances: @remittances, audit_log: @audit, transaction: @transaction,
                             policy: Policies::Billing::ManageBillingPolicy.new, clock: Clock.new(NOW)).call(actor:, dto:)
      end

      test "l'équipe saisit un versement : reçu maintenant par défaut, audit, transaction" do
        result = record

        assert result.success?
        remittance = @remittances.recorded.first
        assert_equal [ 3, 10_000, NOW, "WAVE-1", nil, 7 ], [ remittance.relay_point_id, remittance.amount_xof, remittance.received_at,
                                                             remittance.reference, remittance.reason, remittance.recorded_by_id ]
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "billing.remittance_recorded", actor_id: 7, at: NOW, subject_type: "Remittance", subject_id: 11,
                         metadata: { relay_point_id: 3, amount_xof: 10_000, reference: "WAVE-1", reason: nil } } ], @audit.events
      end

      test "un versement négatif demande un motif et le garde" do
        assert_equal [ :reason ], record(amount_xof: "-10000").errors.keys
        assert_nil @audit.events

        result = record(amount_xof: "−10 000", reason: "saisi par erreur")

        assert result.success?
        assert_equal [ -10_000, "saisi par erreur" ], [ result.value.amount_xof, result.value.reason ]
      end

      test "un montant nul, absent ou non entier est invalide" do
        [ "0", "", "12,5", "abc" ].each do |amount|
          result = record(amount_xof: amount)

          assert_equal :invalid, result.code, amount
          assert_includes result.errors.keys, :amount_xof
          assert_nil @remittances.recorded
        end
      end

      test "le point relais est requis et la référence limitée à 60 caractères" do
        assert_includes record(relay_point_id: nil).errors.keys, :relay_point_id
        assert_includes record(reference: "x" * 61).errors.keys, :reference
      end

      test "refuse tout autre rôle et le visiteur, sans rien écrire" do
        [ nil, Entities::Identity::Actor.new(user_id: 4, role: :student), Entities::Identity::Actor.new(user_id: 3, role: :school_admin) ].each do |actor|
          assert_equal :forbidden, record(actor:).code
          assert_nil @remittances.recorded
        end
      end
    end
  end
end
