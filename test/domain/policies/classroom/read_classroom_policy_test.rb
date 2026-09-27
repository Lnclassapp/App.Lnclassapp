require "test_helper"

module Policies
  module Classroom
    class ReadClassroomPolicyTest < ActiveSupport::TestCase
      Header = Data.define(:teacher_ids, :student_ids)

      def call(role, user_id)
        actor = Entities::Identity::Actor.new(user_id:, role:)
        ReadClassroomPolicy.new.call(actor:, classroom: Header.new(teacher_ids: [ 1 ], student_ids: [ 2 ]))
      end

      test "équipe et enseignant de la classe voient la liste" do
        assert call(:team, 9).value.show_roster
        assert call(:teacher, 1).value.show_roster
      end

      test "l'élève de la classe la lit sans la liste" do
        result = call(:student, 2)

        assert result.success?
        assert_not result.value.show_roster
      end

      test "refuse les autres" do
        assert_equal :forbidden, call(:teacher, 3).code
        assert_equal :forbidden, call(:student, 3).code
        assert_equal :forbidden, call(:school_admin, 1).code
        assert_equal :forbidden, ReadClassroomPolicy.new.call(actor: nil, classroom: Header.new([], [])).code
      end
    end
  end
end
