require "test_helper"

# ADR-0071 §4.1 : rejoindre un établissement par son code : l'enseignant sans établissement ni demande en attente.
module Policies
  module School
    class JoinSchoolWithCodePolicyTest < ActiveSupport::TestCase
      def actor(role, school_id: nil, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id:)
      def request(status) = Entities::School::JoinRequest.new(id: 1, public_id: "abcdefghijkmno", teacher_id: 1, school_id: 7, status:,
                                                              teacher_name: "Awa Koné")

      setup { @policy = JoinSchoolWithCodePolicy.new }

      test "autorise l'enseignant sans établissement ni demande" do
        assert @policy.call(actor: actor(:teacher), pending_request: nil).success?
      end

      test "refuse l'enseignant qui a une demande en attente" do
        assert_equal :forbidden, @policy.call(actor: actor(:teacher), pending_request: request("pending")).code
      end

      test "refuse l'enseignant déjà rattaché à un établissement" do
        assert_equal :forbidden, @policy.call(actor: actor(:teacher, school_id: 7), pending_request: nil).code
      end

      test "refuse l'élève, la direction, l'équipe et l'anonyme" do
        assert_equal :forbidden, @policy.call(actor: actor(:student), pending_request: nil).code
        assert_equal :forbidden, @policy.call(actor: actor(:school_admin), pending_request: nil).code
        assert_equal :forbidden, @policy.call(actor: actor(:team, team_role: "admin"), pending_request: nil).code
        assert_equal :forbidden, @policy.call(actor: nil, pending_request: nil).code
      end
    end
  end
end
