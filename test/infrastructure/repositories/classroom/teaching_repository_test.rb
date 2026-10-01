require "test_helper"

module Repositories
  module Classroom
    class TeachingRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = TeachingRepository.new
        @teacher = create_teacher
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      test "déclare une classe une seule fois" do
        classroom = create_classroom

        assert_equal :created, @repository.declare(teacher_id: @teacher.id, classroom_id: classroom.id, at: @at)
        assert_equal :already, @repository.declare(teacher_id: @teacher.id, classroom_id: classroom.id, at: @at)
        assert_equal 1, Orm::TeacherClassroom.where(teacher: @teacher).count
      end

      test "liste les classes déclarées et retire une déclaration sans toucher aux assignations" do
        first, second = create_classroom, create_classroom
        [ first, second ].each { |classroom| @repository.declare(teacher_id: @teacher.id, classroom_id: classroom.id, at: @at) }
        assignment = create_assignment(classroom: first, by: @teacher)

        assert_equal [ first.id, second.id ].sort, @repository.classroom_ids_for(teacher_id: @teacher.id)
        assert @repository.withdraw(teacher_id: @teacher.id, classroom_id: first.id)
        assert_equal [ second.id ], @repository.classroom_ids_for(teacher_id: @teacher.id)
        assert Orm::ClassroomAssignment.exists?(assignment.id)
      end

      # ADR-0071 §4.5 : un enseignant retiré perd ses classes de cet établissement, et garde les autres.
      test "withdraw_all_in_school retire les déclarations des classes de cet établissement seulement" do
        school, other = create_school, create_school
        first, second = create_classroom(school:), create_classroom(school:, school_year: "2025-2026")
        elsewhere = create_classroom(school: other)
        [ first, second, elsewhere ].each { |classroom| @repository.declare(teacher_id: @teacher.id, classroom_id: classroom.id, at: @at) }
        colleague = create_teacher(classrooms: [ first ])
        assignment = create_assignment(classroom: first, by: @teacher)

        assert_equal 2, @repository.withdraw_all_in_school(teacher_id: @teacher.id, school_id: school.id)
        assert_equal [ elsewhere.id ], @repository.classroom_ids_for(teacher_id: @teacher.id)
        assert_equal [ first.id ], @repository.classroom_ids_for(teacher_id: colleague.id)
        assert Orm::ClassroomAssignment.exists?(assignment.id)
        assert_equal 0, @repository.withdraw_all_in_school(teacher_id: @teacher.id, school_id: school.id)
      end
    end
  end
end
