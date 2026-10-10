require "test_helper"

module Queries
  module Identity
    class ShellUserQueryTest < ActiveSupport::TestCase
      setup { @query = ShellUserQuery.new }

      test "a student shows their classroom and school" do
        school = create_school(name: "Lycée classique d'Abidjan")
        student = create_student(first_name: "Awa", last_name: "Koné", classroom: create_classroom(school:, name: "Tle D 1"))

        assert_equal ShellUserQuery::Row.new(name: "Awa Koné", role: :student, detail: "Tle D 1 · Lycée classique d'Abidjan",
                                             public_id: student.public_id, photo_version: nil),
                     @query.call(user_id: student.id)
      end

      test "a student without a classroom has no detail" do
        assert_nil @query.call(user_id: create_student.id).detail
      end

      test "a student whose only classroom is archived has no detail, and gets it back once the classroom is restored (ADR-0088)" do
        classroom = create_classroom(name: "Tle D 1")
        student = create_student(classroom:)
        repository = Repositories::Classroom::ClassroomRepository.new

        repository.archive(id: classroom.id, at: Time.current)
        assert_nil @query.call(user_id: student.id).detail

        repository.restore(id: classroom.id, at: Time.current)
        assert_match(/\ATle D 1 · /, @query.call(user_id: student.id).detail)
      end

      test "a student with a left archived classroom and an active primary one shows the active one" do
        archived = create_classroom(name: "Tle D 1")
        student = create_student(classroom: archived)
        Orm::ClassroomStudent.where(student:).update_all(primary: false)
        Orm::ClassroomStudent.create!(classroom: create_classroom(name: "Tle D 2"), student:, primary: true, joined_at: Time.current,
                                      joined_via: "standard")
        Repositories::Classroom::ClassroomRepository.new.archive(id: archived.id, at: Time.current)

        assert_match(/\ATle D 2 · /, @query.call(user_id: student.id).detail)
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
