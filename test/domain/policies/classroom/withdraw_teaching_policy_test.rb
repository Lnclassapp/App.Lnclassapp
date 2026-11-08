require "test_helper"

module Policies
  module Classroom
    class WithdrawTeachingPolicyTest < ActiveSupport::TestCase
      def call(role: :teacher, school_id: 5, **overrides)
        actor = Entities::Identity::Actor.new(user_id: 1, role:, school_id:)
        WithdrawTeachingPolicy.new.call(actor:, classroom: Entities::Classroom::Classroom.new(school_id: 5, **overrides))
      end

      test "un enseignant se retire d'une classe de son école, active ou archivée" do
        assert call.success?
        assert call(status: "archived").success?
      end

      test "refuse une autre école, un enseignant sans école, un autre rôle et un visiteur" do
        assert_equal [ :other_school ], call(school_id: 6).errors[:base]
        assert_equal [ :other_school ], call(school_id: nil).errors[:base]
        assert_equal :forbidden, call(role: :team).code
        assert_equal :forbidden, WithdrawTeachingPolicy.new.call(actor: nil, classroom: Entities::Classroom::Classroom.new).code
      end
    end
  end
end
