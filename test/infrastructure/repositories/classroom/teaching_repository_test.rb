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
    end
  end
end
