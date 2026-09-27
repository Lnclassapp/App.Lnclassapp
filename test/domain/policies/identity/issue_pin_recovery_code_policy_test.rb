require "test_helper"

module Policies
  module Identity
    class IssuePinRecoveryCodePolicyTest < ActiveSupport::TestCase
      Target = Data.define(:id, :role) do
        def student? = role == "student"
      end

      def actor(role, user_id: 1) = Entities::Identity::Actor.new(user_id:, role:)
      def call(actor, target, teaches_target: false) = IssuePinRecoveryCodePolicy.new.call(actor:, target:, teaches_target:)

      test "l'enseignant récupère un élève qu'il enseigne" do
        assert call(actor(:teacher), Target.new(2, "student"), teaches_target: true).success?
      end

      test "l'enseignant ne récupère ni un élève d'ailleurs ni un autre enseignant" do
        assert_equal :forbidden, call(actor(:teacher), Target.new(2, "student")).code
        assert_equal :forbidden, call(actor(:teacher), Target.new(2, "teacher"), teaches_target: true).code
      end

      test "l'équipe récupère tout compte sauf le sien" do
        %w[student teacher school_admin team].each { |role| assert call(actor(:team), Target.new(2, role)).success? }

        assert_equal :forbidden, call(actor(:team, user_id: 2), Target.new(2, "team")).code
      end

      test "refuse élève, direction et anonyme" do
        assert_equal :forbidden, call(actor(:student), Target.new(2, "student"), teaches_target: true).code
        assert_equal :forbidden, call(actor(:school_admin), Target.new(2, "student")).code
        assert_equal :forbidden, call(nil, Target.new(2, "student")).code
      end

      test "par défaut, l'enseignant n'enseigne pas la cible" do
        assert_equal :forbidden, IssuePinRecoveryCodePolicy.new.call(actor: actor(:teacher), target: Target.new(2, "student")).code
      end
    end
  end
end
