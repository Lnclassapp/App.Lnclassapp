require "test_helper"

module Policies
  module Identity
    class ReadUserPolicyTest < ActiveSupport::TestCase
      Target = Data.define(:id, :role) do
        def student? = role == "student"
      end

      def actor(role, user_id: 1) = Entities::Identity::Actor.new(user_id:, role:)
      def call(actor, **facts) = ReadUserPolicy.new.call(actor:, **facts)

      test "l'équipe lit tout compte, contact compris, même sans cible" do
        assert call(actor(:team)).value.show_contact
        assert call(actor(:team), target: Target.new(2, "teacher")).value.show_contact
      end

      test "chacun se lit lui-même" do
        assert call(actor(:student), target: Target.new(1, "student")).value.show_contact
      end

      test "l'enseignant lit ses élèves, sans leur contact" do
        result = call(actor(:teacher), target: Target.new(2, "student"), teaches_target: true)

        assert result.success?
        assert_not result.value.show_contact
      end

      test "refuse un élève d'ailleurs, un autre enseignant, une recherche hors équipe et l'anonyme" do
        assert_equal :forbidden, call(actor(:teacher), target: Target.new(2, "student")).code
        assert_equal :forbidden, call(actor(:teacher), target: Target.new(2, "teacher"), teaches_target: true).code
        assert_equal :forbidden, call(actor(:teacher)).code
        assert_equal :forbidden, call(actor(:student), target: Target.new(2, "student")).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end
