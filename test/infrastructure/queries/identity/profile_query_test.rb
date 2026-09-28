require "test_helper"

# PR-01, ADR-0055, UDR-0041: what « Mon profil » shows of the signed-in account, by role.
module Queries
  module Identity
    class ProfileQueryTest < ActiveSupport::TestCase
      setup { @query = ProfileQuery.new }

      test "a student shows their name, number, primary classroom and registration date" do
        classroom = create_classroom(name: "Tle D 1")
        student = create_student(first_name: "Aya", last_name: "Koné", contact: "0701020304", classroom:,
                                 created_at: Time.zone.local(2026, 9, 1, 23, 30))
        create_student(classroom: create_classroom(name: "Autre"))

        row = @query.call(user_id: student.id)

        assert_equal [ "Aya", "Koné", "Aya Koné", :student ], [ row.first_name, row.last_name, row.display_name, row.role ]
        assert_equal "07 01 02 03 04", row.grouped_contact
        assert_equal "Tle D 1", row.classroom_name
        assert_equal Date.new(2026, 9, 1), row.registered_on
        assert_nil row.school_name
        assert_nil row.material_name
      end

      test "a student without a primary classroom, or who left it, has none" do
        student = create_student(classroom: create_classroom(name: "Tle D 2"))
        Orm::ClassroomStudent.where(student_id: student.id).update_all(left_at: Time.current)

        assert_nil @query.call(user_id: student.id).classroom_name
        assert_nil @query.call(user_id: create_student.id).classroom_name
      end

      test "a teacher shows their primary school and subject" do
        teacher = create_teacher(school: create_school(name: "Lycée moderne de Cocody"), material: create_material(name: "SVT"))

        row = @query.call(user_id: teacher.id)

        assert_equal [ :teacher, "Lycée moderne de Cocody", "SVT", nil ],
                     [ row.role, row.school_name, row.material_name, row.classroom_name ]
      end

      test "a team member shows their team role, a school admin only their role; an unknown account is nil" do
        assert_equal [ :team, "content" ], @query.call(user_id: create_team_member(team_role: "content").id).then { [ it.role, it.team_role ] }
        assert_equal :school_admin, @query.call(user_id: create_user(role: "school_admin").id).role
        assert_nil @query.call(user_id: 0)
      end

      test "the row gives the public id, and the version of the photo when there is one (ADR-0060)" do
        student = create_student

        assert_equal [ student.public_id, nil ], @query.call(user_id: student.id).then { [ it.public_id, it.photo_version ] }
        attach_photo(student)
        assert_equal PhotoVersions.for(user_ids: [ student.id ])[student.id], @query.call(user_id: student.id).photo_version
      end
    end
  end
end
