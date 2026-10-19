require "test_helper"

# ADR-0071 §4.1, ADR-0094 §4.3 (ME-04) : rejoindre un établissement : l'enseignant sans demande en attente, sous le plafond.
module Policies
  module School
    class JoinSchoolWithCodePolicyTest < ActiveSupport::TestCase
      def actor(role, school_id: nil, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id:)
      def request(status) = Entities::School::JoinRequest.new(id: 1, public_id: "abcdefghijkmno", teacher_id: 1, school_id: 7, status:,
                                                              teacher_name: "Awa Koné")

      setup { @policy = JoinSchoolWithCodePolicy.new }

      test "autorise l'enseignant sans établissement, avec un ou avec deux" do
        assert @policy.call(actor: actor(:teacher), pending_request: nil, schools_count: 0).success?
        [ 1, 2 ].each { assert @policy.call(actor: actor(:teacher, school_id: 7), pending_request: nil, schools_count: it).success?, it }
      end

      test "ME-04 : refuse un quatrième établissement, en le disant" do
        result = @policy.call(actor: actor(:teacher, school_id: 7), pending_request: nil, schools_count: 3)

        assert_equal [ :forbidden, { base: [ :schools_limit ] } ], [ result.code, result.errors ]
      end

      test "refuse l'enseignant qui a une demande en attente" do
        assert_equal :forbidden, @policy.call(actor: actor(:teacher), pending_request: request("pending"), schools_count: 0).code
      end

      test "refuse l'élève, la direction, l'équipe et l'anonyme" do
        assert_equal :forbidden, @policy.call(actor: actor(:student), pending_request: nil, schools_count: 0).code
        assert_equal :forbidden, @policy.call(actor: actor(:school_admin), pending_request: nil, schools_count: 0).code
        assert_equal :forbidden, @policy.call(actor: actor(:team, team_role: "admin"), pending_request: nil, schools_count: 0).code
        assert_equal :forbidden, @policy.call(actor: nil, pending_request: nil, schools_count: 0).code
      end
    end
  end
end
