require "test_helper"

module Policies
  module Identity
    class ResetSecondFactorPolicyTest < ActiveSupport::TestCase
      Target = Data.define(:id, :role) do
        def team? = role == "team"
      end

      def actor(role, user_id: 1) = Entities::Identity::Actor.new(user_id:, role:, team_role: role == :team ? "admin" : nil)

      test "un membre de l'équipe réinitialise un autre membre" do
        assert ResetSecondFactorPolicy.new.call(actor: actor(:team), target: Target.new(2, "team")).success?
      end

      test "refuse soi-même, une cible hors équipe, les autres rôles et l'anonyme" do
        policy = ResetSecondFactorPolicy.new

        assert_equal :forbidden, policy.call(actor: actor(:team, user_id: 2), target: Target.new(2, "team")).code
        assert_equal :forbidden, policy.call(actor: actor(:team), target: Target.new(2, "teacher")).code
        assert_equal :forbidden, policy.call(actor: actor(:teacher), target: Target.new(2, "team")).code
        assert_equal :forbidden, policy.call(actor: nil, target: Target.new(2, "team")).code
      end
    end
  end
end
