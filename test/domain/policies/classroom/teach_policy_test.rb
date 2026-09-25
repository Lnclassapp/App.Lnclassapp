require "test_helper"

module Policies
  module Classroom
    class TeachPolicyTest < ActiveSupport::TestCase
      def call(actor) = TeachPolicy.new.call(actor:, classroom: Entities::Classroom::Classroom.new(teacher_ids: [ 1 ]))
      def actor(role, user_id = 1) = Entities::Identity::Actor.new(user_id:, role:)

      test "l'enseignant de la classe et l'équipe" do
        assert call(actor(:teacher)).success?
        assert call(actor(:team, 9)).success?
      end

      test "refuse un autre enseignant, un élève, la direction et l'anonyme" do
        assert_equal :forbidden, call(actor(:teacher, 2)).code
        assert_equal :forbidden, call(actor(:student)).code
        assert_equal :forbidden, call(actor(:school_admin)).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end
