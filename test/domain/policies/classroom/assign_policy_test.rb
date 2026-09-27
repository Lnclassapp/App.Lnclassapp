require "test_helper"

module Policies
  module Classroom
    class AssignPolicyTest < ActiveSupport::TestCase
      def call(actor, status: "active")
        AssignPolicy.new.call(actor:, classroom: Entities::Classroom::Classroom.new(teacher_ids: [ 1 ], status:))
      end

      def teacher(user_id = 1) = Entities::Identity::Actor.new(user_id:, role: :teacher)

      test "l'enseignant de la classe assigne dans une classe active" do
        assert call(teacher).success?
        assert call(Entities::Identity::Actor.new(user_id: 9, role: :team)).success?
      end

      test "refuse une classe archivée, même à l'équipe" do
        assert_equal [ :classroom_archived ], call(teacher, status: "archived").errors[:base]
      end

      test "refuse ceux que TeachPolicy refuse" do
        assert_equal :forbidden, call(teacher(2)).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end
