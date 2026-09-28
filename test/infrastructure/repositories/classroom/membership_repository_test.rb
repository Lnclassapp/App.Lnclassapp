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

      test "l'adhésion principale porte l'établissement, l'année, l'identifiant public et le nom de sa classe (ADR-0066 §4.5)" do
        school = create_school
        classroom = create_classroom(school:, name: "Tle D 1", school_year: "2026-2027")
        @repository.add_primary(classroom_id: classroom.id, student_id: @student.id, at: @at)

        membership = @repository.primary_for(student_id: @student.id)

        assert_equal [ school.id, "2026-2027", classroom.public_id, "Tle D 1" ],
                     [ membership.school_id, membership.school_year, membership.classroom_public_id, membership.classroom_name ]
      end

      test "construite sans les champs de la classe, une adhésion les laisse à nil" do
        membership = Entities::Classroom::Membership.new(classroom_id: 1, student_id: 2, primary: true, joined_at: @at, left_at: nil,
                                                         classroom_status: "active")

        assert_equal [ nil, nil, nil, nil ],
                     [ membership.school_id, membership.school_year, membership.classroom_public_id, membership.classroom_name ]
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
