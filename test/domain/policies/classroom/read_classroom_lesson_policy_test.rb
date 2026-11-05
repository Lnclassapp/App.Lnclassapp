require "test_helper"

module Policies
  module Classroom
    # ADR suivi-classe-lecon (lecture-de-la-classe-par-la-direction) §4, CA-13 et CA-14.
    class ReadClassroomLessonPolicyTest < ActiveSupport::TestCase
      Header = Data.define(:teacher_ids, :student_ids, :school_id)

      def call(role, user_id, school_id: 7)
        actor = Entities::Identity::Actor.new(user_id:, role:, school_id:)
        ReadClassroomLessonPolicy.new.call(actor:, classroom: Header.new(teacher_ids: [ 1 ], student_ids: [ 2 ], school_id: 7))
      end

      test "l'équipe et l'enseignant de la classe peuvent assigner" do
        assert call(:team, 9).value.can_assign
        assert call(:teacher, 1).value.can_assign
      end

      test "la direction du même établissement lit sans pouvoir assigner" do
        result = call(:school_admin, 5)

        assert result.success?
        assert_not result.value.can_assign
      end

      test "la direction d'un autre établissement ne voit pas que la classe existe" do
        assert_equal :not_found, call(:school_admin, 5, school_id: 8).code
        assert_equal :not_found, call(:school_admin, 5, school_id: nil).code
      end

      test "l'élève, l'enseignant d'une autre classe et l'acteur nil sont refusés" do
        assert_equal :forbidden, call(:student, 2).code
        assert_equal :forbidden, call(:teacher, 3).code
        assert_equal :forbidden, ReadClassroomLessonPolicy.new.call(actor: nil, classroom: Header.new([], [], 7)).code
      end

      test "l'enseignant de la classe depuis un autre de ses établissements garde le refus actuel" do
        assert_equal [ :forbidden, { base: [ :other_school ] } ], call(:teacher, 1, school_id: 8).then { [ it.code, it.errors ] }
      end
    end
  end
end
