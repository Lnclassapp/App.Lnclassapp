require "test_helper"

# RI-04 (ADR-0080) : seul le système efface les IP du journal.
module Policies
  module Identity
    class EraseAuditIpsPolicyTest < ActiveSupport::TestCase
      test "the system alone may erase the IPs" do
        assert EraseAuditIpsPolicy.new.call(actor: nil).success?
      end

      test "any signed-in person is refused, the team included" do
        [ [ :team, "admin" ], [ :school_admin, nil ], [ :teacher, nil ], [ :student, nil ] ].each do |role, team_role|
          actor = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

          assert_equal :forbidden, EraseAuditIpsPolicy.new.call(actor:).code, role
        end
      end
    end
  end
end
