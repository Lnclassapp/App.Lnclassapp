require "test_helper"

module Repositories
  module Billing
    class RemittanceRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = RemittanceRepository.new
        @team = create_team_member
        @relay_point = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
      end

      def record(amount, reason: nil, at: Time.utc(2026, 11, 13, 10))
        @repository.record(relay_point_id: @relay_point.id, amount_xof: amount, received_at: at, reference: "WAVE-9", reason:,
                           recorded_by_id: @team.id)
      end

      test "enregistre un versement signé et rend l'entité" do
        result = record(5_000)

        assert result.success?
        assert_instance_of Entities::Billing::Remittance, result.value
        assert_equal [ 5_000, "WAVE-9", @team.id, @relay_point.id ], [ result.value.amount_xof, result.value.reference, result.value.recorded_by_id,
                                                                       result.value.relay_point_id ]
        assert_equal 14, result.value.public_id.length
      end

      test "refuse un montant nul et un point relais inconnu" do
        assert_equal :invalid, record(0).code
        unknown = @repository.record(relay_point_id: 0, amount_xof: 1, received_at: Time.utc(2026, 11, 13), reference: nil, reason: nil,
                                     recorded_by_id: @team.id)
        assert_equal :invalid, unknown.code
        assert_equal [ :relay_point_id ], unknown.errors.keys
      end

      test "liste du plus récent au plus ancien, un versement ne se modifie ni ne se supprime" do
        record(1_000, at: Time.utc(2026, 11, 14))
        latest = record(-1_000, reason: "erreur", at: Time.utc(2026, 11, 15)).value

        list = @repository.for_relay_point(relay_point_id: @relay_point.id)

        assert_equal latest.id, list.first.id
        assert_equal 4, list.size
        record = Orm::Billing::Remittance.find(latest.id)
        assert_not record.update(amount_xof: 5)
        assert_not record.destroy
      end
    end
  end
end
