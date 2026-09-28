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

      test "retire toutes les déclarations d'un enseignant dans un établissement, sans toucher à un autre (ADR-0066 §4.4)" do
        school, other = create_school, create_school
        here = [ create_classroom(school:), create_classroom(school:) ]
        there = create_classroom(school: other)
        colleague = create_teacher
        [ *here, there ].each { |classroom| @repository.declare(teacher_id: @teacher.id, classroom_id: classroom.id, at: @at) }
        @repository.declare(teacher_id: colleague.id, classroom_id: here.first.id, at: @at)
        assignment = create_assignment(classroom: here.first, by: @teacher)

        assert_equal 2, @repository.withdraw_all_in_school(teacher_id: @teacher.id, school_id: school.id)

        assert_equal [ there.id ], @repository.classroom_ids_for(teacher_id: @teacher.id)
        assert_equal [ here.first.id ], @repository.classroom_ids_for(teacher_id: colleague.id)
        assert Orm::ClassroomAssignment.exists?(assignment.id)
        assert_equal 0, @repository.withdraw_all_in_school(teacher_id: @teacher.id, school_id: school.id)
      end
    end
  end
end
