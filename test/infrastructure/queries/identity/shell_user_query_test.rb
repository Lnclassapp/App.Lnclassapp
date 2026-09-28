require "test_helper"

module Queries
  module Identity
    class ShellUserQueryTest < ActiveSupport::TestCase
      setup { @query = ShellUserQuery.new }

      test "a student shows their classroom and school" do
        school = create_school(name: "Lycée classique d'Abidjan")
        student = create_student(first_name: "Awa", last_name: "Koné", classroom: create_classroom(school:, name: "Tle D 1"))

        assert_equal ShellUserQuery::Row.new(name: "Awa Koné", role: :student, detail: "Tle D 1 · Lycée classique d'Abidjan",
                                             public_id: student.public_id, photo_version: nil, position: nil),
                     @query.call(user_id: student.id)
      end

      test "a student without a classroom has no detail" do
        assert_nil @query.call(user_id: create_student.id).detail
      end

      test "a teacher shows their subject and primary school" do
        teacher = create_teacher(school: create_school(name: "Lycée moderne de Cocody"), material: create_material(name: "Mathématiques"))

        assert_equal "Mathématiques · Lycée moderne de Cocody", @query.call(user_id: teacher.id).detail
      end

      test "a team member has no detail, an unknown account is nil" do
        row = @query.call(user_id: create_team_member(first_name: "Kam", last_name: "Kara").id)

        assert_equal [ "Kam Kara", :team, nil, nil ], row.to_h.values_at(:name, :role, :detail, :photo_version)
        assert_nil @query.call(user_id: 0)
      end

      # UDR-0052 §3.1: the shell shows « <Fonction> · <Établissement> »; the query gives the position and the school.
      test "a member of the direction shows the school of their active attachment, and their position" do
        member = create_school_admin(school: create_school(name: "Lycée Moderne de Treichville"), position: "censor")

        assert_equal [ :school_admin, "Lycée Moderne de Treichville", "censor" ],
                     @query.call(user_id: member.id).to_h.values_at(:role, :detail, :position)
      end

      test "a member of the direction who left, or whose school is inactive, has neither detail nor position" do
        left = create_school_admin
        Orm::SchoolStaff.where(user_id: left.id).update_all(left_at: Time.current)
        inactive = create_school_admin(school: create_school(status: "inactive"))

        [ left, inactive, create_user(role: "school_admin") ].each do |member|
          assert_equal [ nil, nil ], @query.call(user_id: member.id).to_h.values_at(:detail, :position)
        end
      end

      test "an account with a photo gives its public id and the version of its photo (ADR-0060)" do
        student = attach_photo(create_student)

        row = @query.call(user_id: student.id)

        assert_equal student.public_id, row.public_id
        assert_equal PhotoVersions.for(user_ids: [ student.id ])[student.id], row.photo_version
        assert_not_nil row.photo_version
      end
    end
  end
end
