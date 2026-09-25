require "test_helper"

module Entities
  module Classroom
    class ClassroomTest < ActiveSupport::TestCase
      def build(**overrides)
        Classroom.new(name: " 3ème  2 ", school_id: 1, level_id: 4, school_year: "2026-2027", **overrides)
      end

      test "valeurs par défaut : active, 80 places, aucun enseignant ni élève" do
        classroom = build

        assert classroom.valid?
        assert_equal "3ème 2", classroom.name
        assert classroom.active?
        assert_equal 80, classroom.max_students
        assert_empty classroom.teacher_ids
        assert_equal 0, classroom.active_students_count
      end

      test "exige nom borné, école, niveau, statut, plafond et année valides" do
        assert build(name: nil).invalid?
        assert build(name: "a" * 16).invalid?
        assert build(school_id: nil).invalid?
        assert build(level_id: nil).invalid?
        assert build(status: "closed").invalid?
        assert build(max_students: 0).invalid?
        assert build(max_students: 151).invalid?
        assert build(school_year: "2026").invalid?
      end

      test "complète à partir du plafond" do
        assert_not build(active_students_count: 79).full?
        assert build(active_students_count: 80).full?
        assert build(max_students: 2, active_students_count: 2).full?
        assert_not build(status: "archived").active?
        assert_equal [ 7 ], build(teacher_ids: [ 7 ]).teacher_ids
      end
    end
  end
end
