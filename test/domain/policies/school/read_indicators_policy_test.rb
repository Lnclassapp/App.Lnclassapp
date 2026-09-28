require "test_helper"

# ADR-0062, ADR-0038 (« Lire les indicateurs agrégés » : les trois sous-rôles) : le pilotage est réservé à l'équipe.
module Policies
  module School
    class ReadIndicatorsPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "autorise tout membre de l'équipe, quel que soit son sous-rôle" do
        %w[admin content field].each do |team_role|
          assert ReadIndicatorsPolicy.new.call(actor: actor(:team, team_role:)).success?, team_role
        end
      end

      test "refuse l'élève, l'enseignant, la direction et l'anonyme" do
        policy = ReadIndicatorsPolicy.new

        %i[student teacher school_admin].each { |role| assert_equal :forbidden, policy.call(actor: actor(role)).code, role }
        assert_equal :forbidden, policy.call(actor: nil).code
      end
    end
  end
end
