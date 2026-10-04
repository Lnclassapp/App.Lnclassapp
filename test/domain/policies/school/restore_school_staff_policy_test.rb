require "test_helper"

# ID-19 to ID-21 (ADR-0077 §4.3): only the admin and field team restores a removed direction, before its deletion.
module Policies
  module School
    class RestoreSchoolStaffPolicyTest < ActiveSupport::TestCase
      def actor(role, school_id: nil, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id:)

      test "autorise l'équipe admin et field" do
        policy = RestoreSchoolStaffPolicy.new

        assert policy.call(actor: actor(:team, team_role: "admin")).success?
        assert policy.call(actor: actor(:team, team_role: "field")).success?
      end

      test "refuse l'équipe content, la direction, l'enseignant, l'élève et le visiteur" do
        policy = RestoreSchoolStaffPolicy.new

        [ actor(:team, team_role: "content"), actor(:school_admin, school_id: 7), actor(:teacher, school_id: 7),
          actor(:student), nil ].each do |someone|
          assert_equal :forbidden, policy.call(actor: someone).code, someone&.role.inspect
        end
      end
    end
  end
end
