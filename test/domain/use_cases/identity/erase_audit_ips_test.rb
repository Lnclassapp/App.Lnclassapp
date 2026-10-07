require "test_helper"

# RI-01 à RI-04 (ADR-0080) : l'effacement passe l'échéance et la taille des lots au journal ; une personne est refusée.
module UseCases
  module Identity
    class EraseAuditIpsTest < ActiveSupport::TestCase
      AT = Time.utc(2024, 10, 5, 4, 30)

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :calls

        def initialize(erased) = (@erased = erased) && (@calls = [])

        def erase_ips_before(at:, batch_size:)
          @calls << [ at, batch_size ]
          @erased
        end
      end

      def erase(actor: nil, erased: 3)
        @audit = FakeAuditLog.new(erased)
        EraseAuditIps.new(audit_log: @audit, policy: Policies::Identity::EraseAuditIpsPolicy.new).call(at: AT, actor:)
      end

      test "the IPs before the date are erased by batches of 1 000, and the count is returned" do
        result = erase

        assert result.success?
        assert_equal 3, result.value
        assert_equal [ [ AT, 1_000 ] ], @audit.calls
      end

      test "a signed-in person is refused and nothing is erased" do
        result = erase(actor: Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin"))

        assert_equal :forbidden, result.code
        assert_empty @audit.calls
      end
    end
  end
end
