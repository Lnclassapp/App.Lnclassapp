require "test_helper"

module Queries
  module Identity
    class ShellUserQueryTest < ActiveSupport::TestCase
      setup { @query = ShellUserQuery.new }

      test "a student shows their classroom and school" do
        school = create_school(name: "Lycée classique d'Abidjan")
        student = create_student(first_name: "Awa", last_name: "Koné", classroom: create_classroom(school:, name: "Tle D 1"))

        assert_equal ShellUserQuery::Row.new(name: "Awa Koné", role: :student, detail: "Tle D 1 · Lycée classique d'Abidjan"),
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

        assert_equal [ "Kam Kara", :team, nil ], row.to_h.values
        assert_nil @query.call(user_id: 0)
      end

      test "the row feeds the shell" do
        row = @query.call(user_id: create_team_member.id)

        assert_equal :team, NavigationHelper::ShellUser.new(**row.to_h).role
      end
    end
  end
end
