require "test_helper"

module Queries
  module Classroom
    # UDR-0110 : la modale préremplit le suffixe et le plafond, montre le préfixe fixe et l'effectif présent.
    class ClassroomSettingsQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @tle = create_level(name: "Tle")
        @series = create_series(name: "D")
      end

      test "préfixe du barème, suffixe, plafond, effectif présent et place du suffixe" do
        classroom = create_classroom(school: @school, level: @tle, series: @series, name: "Tle D Bilingue", max_students: 90)
        2.times { create_student(classroom:) }

        row = ClassroomSettingsQuery.new.call(public_id: classroom.public_id, school: { public_id: @school.public_id })

        assert_equal [ "Tle D", "Bilingue", 90, 2, 9, @tle.slug ], [ row.prefix, row.suffix, row.max_students, row.headcount, row.suffix_max, row.level_slug ]
        assert_not row.free_name?
        assert_not row.archived?
      end

      test "un nom libre n'a pas de suffixe ; une classe archivée se lit, marquée" do
        classroom = create_classroom(school: @school, level: @tle, name: "Bilingue", status: "archived")

        row = ClassroomSettingsQuery.new.call(public_id: classroom.public_id, school: { id: @school.id })

        assert_equal [ "Tle", "" ], [ row.prefix, row.suffix ]
        assert row.free_name?
        assert row.archived?
      end

      test "rien hors de l'établissement donné ni de l'année en cours" do
        mine = create_classroom(school: @school, level: @tle)
        past = create_classroom(school: @school, level: @tle, school_year: "2020-2021")

        assert_nil ClassroomSettingsQuery.new.call(public_id: mine.public_id, school: { id: create_school.id })
        assert_nil ClassroomSettingsQuery.new.call(public_id: past.public_id, school: { id: @school.id })
        assert_nil ClassroomSettingsQuery.new.call(public_id: "inconnu", school: { id: @school.id })
      end
    end
  end
end
