require "test_helper"

module Queries
  module Classroom
    # UDR-0102 §3.1, §3.2: the classroom the student leaves and the one they join, read for « Changer de classe » and its
    # confirmation: name, level, school, the cascade ids, and « full ». Only what the cascade or a valid link offers.
    class ClassroomChangePreviewQueryTest < ActiveSupport::TestCase
      setup do
        @query = ClassroomChangePreviewQuery.new
        @drena = create_drena(name: "Abidjan 1")
        @cocody = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
        @viateur = create_school(drena: @drena, name: "Collège Saint-Viateur")
        @level = create_level(name: "2nde")
        @a = create_classroom(school: @cocody, level: @level, name: "2nde A")
        @c = create_classroom(school: @viateur, level: @level, name: "2nde C", max_students: 1)
        @student = create_student(classroom: @a)
      end

      def chosen(classroom = @c, school: @viateur, level: @level)
        @query.chosen(school_public_id: school.public_id, level_slug: level.slug, classroom_public_id: classroom.public_id)
      end

      test "current: the active primary classroom of the student, with its school and the ids of the cascade" do
        side = @query.current(student_id: @student.id)

        assert_equal [ @a.public_id, "2nde A", "2nde", @level.slug, "Lycée Moderne de Cocody", @cocody.public_id, @drena.public_id, false ],
                     side.deconstruct
      end

      test "current: nothing for a student who left, or whose classroom is archived" do
        archived = create_student(classroom: create_classroom(status: "archived"))
        left = create_student
        Orm::ClassroomStudent.create!(classroom: @a, student: left, primary: true, joined_at: 2.days.ago, left_at: 1.day.ago,
                                      joined_via: "standard")

        assert_nil @query.current(student_id: archived.id)
        assert_nil @query.current(student_id: left.id)
      end

      test "chosen: the classroom the cascade offers, « full » when its ceiling is reached" do
        assert_equal [ "2nde C", "Collège Saint-Viateur", false ], chosen.then { [ it.name, it.school_name, it.full ] }

        create_student(classroom: @c)

        assert chosen.full
      end

      test "chosen: nothing outside the cascade (other school, level, year, archived, inactive school, unknown)" do
        inactive = create_school(status: "inactive")
        cases = [
          chosen(@c, school: @cocody),
          chosen(@c, level: create_level),
          chosen(create_classroom(school: @viateur, level: @level, school_year: "2020-2021")),
          chosen(create_classroom(school: @viateur, level: @level, status: "archived")),
          chosen(create_classroom(school: inactive, level: @level), school: inactive),
          @query.chosen(school_public_id: @viateur.public_id, level_slug: @level.slug, classroom_public_id: nil)
        ]

        assert_equal [ nil ] * 6, cases
      end

      test "linked: the classroom of a valid link; nothing for an archived classroom, an inactive school or no token" do
        assert_equal "2nde C", @query.linked(token: @c.link_token).name
        assert_nil @query.linked(token: create_classroom(status: "archived").link_token)
        assert_nil @query.linked(token: create_classroom(school: create_school(status: "inactive")).link_token)
        assert_nil @query.linked(token: nil)
      end
    end
  end
end
