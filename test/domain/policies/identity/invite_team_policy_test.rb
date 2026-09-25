require "test_helper"

module Policies
  module Identity
    class InviteTeamPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "autorise un admin de l'équipe" do
        assert InviteTeamPolicy.new.call(actor: actor(:team, team_role: "admin")).success?
      end

      test "refuse les autres sous-rôles, les autres rôles et l'anonyme" do
        policy = InviteTeamPolicy.new

        assert_equal :forbidden, policy.call(actor: actor(:team, team_role: "content")).code
        assert_equal :forbidden, policy.call(actor: actor(:teacher)).code
        assert_equal :forbidden, policy.call(actor: actor(:student)).code
        assert_equal :forbidden, policy.call(actor: nil).code
      end
    end
  end
end
