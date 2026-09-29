require "test_helper"

module Policies
  module Identity
    # DS-04, ADR-0065: an admin or field member of the team invites the management of a school; nobody else.
    class InviteSchoolStaffPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role: nil, school_id: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id:)

      test "allows an admin or field member of the team" do
        policy = InviteSchoolStaffPolicy.new

        assert policy.call(actor: actor(:team, team_role: "admin")).success?
        assert policy.call(actor: actor(:team, team_role: "field")).success?
      end

      test "refuses a content member, a school admin, a teacher, a student and the visitor" do
        policy = InviteSchoolStaffPolicy.new

        [ actor(:team, team_role: "content"), actor(:school_admin, school_id: 2), actor(:teacher, school_id: 2), actor(:student), nil ]
          .each { assert_equal :forbidden, policy.call(actor: it).code }
      end
    end
  end
end
