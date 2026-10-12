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

        assert @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, via: "standard", at: @at).success?

        membership = @repository.primary_for(student_id: @student.id)

        assert_instance_of Entities::Classroom::Membership, membership
        assert_equal [ classroom.id, @student.id, true, @at, nil ],
                     [ membership.classroom_id, membership.student_id, membership.primary, membership.joined_at, membership.left_at ]
        assert membership.classroom_active?
        assert_equal [ "standard", nil ], [ membership.joined_via, membership.removed_at ]
      end

      test "une seconde classe principale active donne :conflict" do
        @repository.add_primary(classroom_id: create_classroom.id, student_id: @student.id, via: "standard", at: @at)

        result = @repository.add_primary(classroom_id: create_classroom.id, student_id: @student.id, via: "standard", at: @at)

        assert_equal({ base: [ :already_member ] }, result.errors)
      end

      test "quitter la classe principale pose left_at et libère la place" do
        archived = create_classroom(status: "archived")
        @repository.add_primary(classroom_id: archived.id, student_id: @student.id, via: "standard", at: @at)

        assert_not @repository.primary_for(student_id: @student.id).classroom_active?
        assert @repository.leave_primary(student_id: @student.id, at: @at)
        assert_nil @repository.primary_for(student_id: @student.id)
        assert_equal @at, Orm::ClassroomStudent.find_by(student: @student).left_at
        assert @repository.add_primary(classroom_id: create_classroom.id, student_id: @student.id, via: "standard", at: @at).success?
      end

      test "leave_all closes every open membership of the student, keeps the closed ones and the rows" do
        old = create_classroom(status: "archived")
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: old, student: @student, primary: true, joined_at: @at - 1.year, left_at: @at - 1.day)
        current = create_classroom
        @repository.add_primary(classroom_id: current.id, student_id: @student.id, via: "standard", at: @at)
        other = create_student(classroom: current)

        assert @repository.leave_all(student_id: @student.id, at: @at)

        assert_equal [ @at - 1.day, @at ], Orm::ClassroomStudent.where(student: @student).order(:joined_at).pluck(:left_at)
        assert_nil Orm::ClassroomStudent.find_by(student: other).left_at
      end

      test "IL-14: retirer un élève clôt son adhésion et retient qui l'a retiré" do
        classroom = create_classroom
        teacher = create_teacher(classrooms: [ classroom ])
        @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, via: "standard", at: @at)

        assert_equal true, @repository.remove(classroom_id: classroom.id, student_id: @student.id, removed_by_id: teacher.id, at: @at + 1.hour)

        row = Orm::ClassroomStudent.find_by!(student: @student)
        assert_equal [ @at + 1.hour, @at + 1.hour, teacher.id ], [ row.left_at, row.removed_at, row.removed_by_id ]
        assert_nil @repository.primary_for(student_id: @student.id)
        assert @repository.removed_from?(classroom_id: classroom.id, student_id: @student.id)
      end

      test "IL-21: retirer un élève déjà parti, ou jamais venu, ne change rien et rend false" do
        classroom = create_classroom
        first, second = create_teacher, create_school_admin
        @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, via: "standard", at: @at)
        @repository.remove(classroom_id: classroom.id, student_id: @student.id, removed_by_id: first.id, at: @at + 1.hour)

        assert_equal false, @repository.remove(classroom_id: classroom.id, student_id: @student.id, removed_by_id: second.id, at: @at + 2.hours)
        assert_equal false, @repository.remove(classroom_id: classroom.id, student_id: create_student.id, removed_by_id: first.id, at: @at)

        row = Orm::ClassroomStudent.find_by!(student: @student)
        assert_equal [ @at + 1.hour, first.id ], [ row.removed_at, row.removed_by_id ]
        assert_equal 1, Orm::ClassroomStudent.where(classroom:).count
      end

      test "un élève parti sans avoir été retiré n'est pas « retiré »" do
        archived = create_classroom(status: "archived")
        @repository.add_primary(classroom_id: archived.id, student_id: @student.id, via: "standard", at: @at)
        @repository.leave_primary(student_id: @student.id, at: @at)

        assert_not @repository.removed_from?(classroom_id: archived.id, student_id: @student.id)
        assert_not @repository.removed_from?(classroom_id: create_classroom.id, student_id: @student.id)
      end

      test "IL-16: revenir dans la classe dont on a été retiré rouvre la même adhésion et lève le retrait" do
        classroom = create_classroom
        @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, via: "standard", at: @at)
        @repository.remove(classroom_id: classroom.id, student_id: @student.id, removed_by_id: create_teacher.id, at: @at + 1.hour)

        assert @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, via: "link", at: @at + 1.day).success?

        rows = Orm::ClassroomStudent.where(student: @student)
        assert_equal [ [ classroom.id, true, @at + 1.day, nil, nil, nil, "link" ] ],
                     rows.pluck(:classroom_id, :primary, :joined_at, :left_at, :removed_at, :removed_by_id, :joined_via)
        assert_not @repository.removed_from?(classroom_id: classroom.id, student_id: @student.id)
      end

      test "revenir dans une classe alors qu'une autre est principale donne :conflict et laisse le retrait" do
        classroom = create_classroom
        @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, via: "standard", at: @at)
        @repository.remove(classroom_id: classroom.id, student_id: @student.id, removed_by_id: create_teacher.id, at: @at + 1.hour)
        @repository.add_primary(classroom_id: create_classroom.id, student_id: @student.id, via: "standard", at: @at + 2.hours)

        result = @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, via: "link", at: @at + 1.day)

        assert_equal({ base: [ :already_member ] }, result.errors)
        assert @repository.removed_from?(classroom_id: classroom.id, student_id: @student.id)
      end
    end
  end
end
