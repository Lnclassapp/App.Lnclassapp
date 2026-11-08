require "test_helper"

module Policies
  module Identity
    class ResetSecondFactorPolicyTest < ActiveSupport::TestCase
      Target = Data.define(:id, :role) do
        def team? = role == "team"
      end

      def actor(role, user_id: 1, team_role: role == :team ? "admin" : nil)
        Entities::Identity::Actor.new(user_id:, role:, team_role:)
      end

      test "un membre admin de l'équipe réinitialise un autre membre, quel que soit son sous-rôle" do
        assert ResetSecondFactorPolicy.new.call(actor: actor(:team), target: Target.new(2, "team")).success?
      end

      test "sans cible, même l'admin est refusé" do
        assert_equal :forbidden, ResetSecondFactorPolicy.new.call(actor: actor(:team), target: nil).code
      end

      # B-001 : un membre content ou field ne réinitialise pas le second facteur d'un admin (prise de compte).
      test "refuse les sous-rôles content et field, même pour viser un admin" do
        policy = ResetSecondFactorPolicy.new

        %w[content field].each do |team_role|
          assert_equal :forbidden, policy.call(actor: actor(:team, team_role:), target: Target.new(2, "team")).code
        end
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
