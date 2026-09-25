require "test_helper"

module Policies
  module Classroom
    class DeclareTeachingPolicyTest < ActiveSupport::TestCase
      def call(role: :teacher, school_id: 5, **overrides)
        actor = Entities::Identity::Actor.new(user_id: 1, role:, school_id:)
        classroom = Entities::Classroom::Classroom.new(school_id: 5, **overrides)
        DeclareTeachingPolicy.new.call(actor:, classroom:)
      end

      test "un enseignant se déclare dans une classe active de son école" do
        assert call.success?
      end

      test "refuse une autre école, un enseignant sans école et une classe archivée" do
        assert_equal [ :other_school ], call(school_id: 6).errors[:base]
        assert_equal [ :other_school ], call(school_id: nil).errors[:base]
        assert_equal [ :classroom_archived ], call(status: "archived").errors[:base]
      end

      test "réservé aux enseignants" do
        assert_equal :forbidden, call(role: :team).code
        assert_equal :forbidden, DeclareTeachingPolicy.new.call(actor: nil, classroom: Entities::Classroom::Classroom.new).code
      end
    end
  end
end
