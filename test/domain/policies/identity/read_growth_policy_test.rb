require "test_helper"

module Policies
  module Identity
    # CP-18 (ADR-0063): the growth indicators and the ranking of schools are read by the team only, in V1.
    class ReadGrowthPolicyTest < ActiveSupport::TestCase
      test "autorise l'équipe, quel que soit son sous-rôle" do
        %w[admin content field].each do |team_role|
          assert ReadGrowthPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :team, team_role:)).success?
        end
      end

      test "refuse élève, enseignant, direction et anonyme" do
        %i[student teacher school_admin].each do |role|
          assert_equal :forbidden, ReadGrowthPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:)).code
        end
        assert_equal :forbidden, ReadGrowthPolicy.new.call(actor: nil).code
      end
    end
  end
end
