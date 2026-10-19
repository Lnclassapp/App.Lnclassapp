require "test_helper"

module Policies
  module Classroom
    class ReadClassroomPolicyTest < ActiveSupport::TestCase
      Header = Data.define(:teacher_ids, :student_ids, :school_id)

      def call(role, user_id, school_id: 7)
        actor = Entities::Identity::Actor.new(user_id:, role:, school_id:)
        ReadClassroomPolicy.new.call(actor:, classroom: Header.new(teacher_ids: [ 1 ], student_ids: [ 2 ], school_id: 7))
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

      # ADR-0094 (amendement du 2026-10-16) : la classe d'un autre de ses établissements ne s'ouvre pas ; le refus le dit.
      test "son enseignant ne la lit pas depuis un autre de ses établissements" do
        result = call(:teacher, 1, school_id: 8)

        assert_equal [ :forbidden, { base: [ :other_school ] } ], [ result.code, result.errors ]
        assert_equal({}, call(:teacher, 3, school_id: 8).errors)
      end

      test "refuse les autres" do
        assert_equal :forbidden, call(:teacher, 3).code
        assert_equal :forbidden, call(:student, 3).code
        assert_equal :forbidden, call(:school_admin, 1).code
        assert_equal :forbidden, ReadClassroomPolicy.new.call(actor: nil, classroom: Header.new([], [], 7)).code
      end
    end
  end
end
