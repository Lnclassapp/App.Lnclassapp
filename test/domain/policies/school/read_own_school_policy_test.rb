require "test_helper"

# ADR-0065 : la direction lit son seul établissement ; aucun autre rôle ne lit ses pages (DS-11).
module Policies
  module School
    class ReadOwnSchoolPolicyTest < ActiveSupport::TestCase
      def actor(role, school_id: nil, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id:)

      test "autorise la direction rattachée à un établissement" do
        assert ReadOwnSchoolPolicy.new.call(actor: actor(:school_admin, school_id: 7)).success?
      end

      test "refuse l'élève, l'enseignant, l'équipe, la direction sans établissement et l'anonyme" do
        policy = ReadOwnSchoolPolicy.new

        assert_equal :forbidden, policy.call(actor: actor(:student)).code
        assert_equal :forbidden, policy.call(actor: actor(:teacher, school_id: 7)).code
        assert_equal :forbidden, policy.call(actor: actor(:team, team_role: "admin")).code
        assert_equal :forbidden, policy.call(actor: actor(:school_admin)).code
        assert_equal :forbidden, policy.call(actor: nil).code
      end
    end
  end
end
