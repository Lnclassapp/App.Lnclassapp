require "test_helper"

module Repositories
  module Classroom
    class MembershipRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = MembershipRepository.new
        @at = Time.zone.parse("2026-09-25 10:00")
        @student = create_student
      end

      test "ajoute puis relit l'adhésion principale active, avec le statut de sa classe" do
        classroom = create_classroom

        assert @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, at: @at).success?

        membership = @repository.primary_for(student_id: @student.id)

        assert_instance_of Entities::Classroom::Membership, membership
        assert_equal [ classroom.id, @student.id, true, @at, nil ],
                     [ membership.classroom_id, membership.student_id, membership.primary, membership.joined_at, membership.left_at ]
        assert membership.classroom_active?
      end

      test "une seconde classe principale active donne :conflict" do
        @repository.add_primary(classroom_id: create_classroom.id, student_id: @student.id, at: @at)

        result = @repository.add_primary(classroom_id: create_classroom.id, student_id: @student.id, at: @at)

        assert_equal({ base: [ :already_member ] }, result.errors)
      end

      test "quitter la classe principale pose left_at et libère la place" do
        archived = create_classroom(status: "archived")
        @repository.add_primary(classroom_id: archived.id, student_id: @student.id, at: @at)

        assert_not @repository.primary_for(student_id: @student.id).classroom_active?
        assert @repository.leave_primary(student_id: @student.id, at: @at)
        assert_nil @repository.primary_for(student_id: @student.id)
        assert_equal @at, Orm::ClassroomStudent.find_by(student: @student).left_at
        assert @repository.add_primary(classroom_id: create_classroom.id, student_id: @student.id, at: @at).success?
      end
    end
  end
end
