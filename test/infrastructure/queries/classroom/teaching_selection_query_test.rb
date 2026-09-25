require "test_helper"

module Queries
  module Classroom
    # CL-09 : les classes que l'enseignant peut déclarer, groupées par niveau, chacune avec son état déclaré.
    class TeachingSelectionQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Classique d'Abidjan")
        @sixth = create_level(name: "6ème", position: 1, cycle: "first")
        @third = create_level(name: "3ème", position: 4, cycle: "first")
      end

      def names(row) = row.levels.map { |level| [ level.name, level.classrooms.map(&:name) ] }

      test "les classes actives de l'école et de l'année, par position de niveau, puis par nom dans l'ordre naturel" do
        third_b = create_classroom(school: @school, level: @third, name: "3ème B")
        create_classroom(school: @school, level: @sixth, name: "6ème 10")
        create_classroom(school: @school, level: @sixth, name: "6ème 2")
        create_classroom(school: @school, level: @sixth, name: "6ème 1")
        create_classroom(school: @school, level: @third, name: "3ème A")
        teacher = create_teacher(school: @school, classrooms: [ third_b ])

        row = TeachingSelectionQuery.new.call(teacher_id: teacher.id, school_id: @school.id)

        assert_equal "Lycée Classique d'Abidjan", row.school_name
        assert_equal [ [ "6ème", [ "6ème 1", "6ème 2", "6ème 10" ] ], [ "3ème", [ "3ème A", "3ème B" ] ] ], names(row)
        assert_equal [ [ third_b.public_id, true ] ],
                     row.levels.flat_map(&:classrooms).select(&:declared).map { [ it.public_id, it.declared ] }
        assert_equal 1, row.declared_count
      end

      test "écarte les classes archivées, celles d'une autre année et celles d'une autre école" do
        create_classroom(school: @school, level: @sixth, name: "6ème 1")
        create_classroom(school: @school, level: @sixth, name: "6ème 9", status: "archived")
        create_classroom(school: @school, level: @sixth, name: "6ème 8", school_year: "2020-2021")
        create_classroom(level: @sixth, name: "6ème 7")
        teacher = create_teacher(school: @school)

        row = TeachingSelectionQuery.new.call(teacher_id: teacher.id, school_id: @school.id)

        assert_equal [ [ "6ème", [ "6ème 1" ] ] ], names(row)
        assert_equal 0, row.declared_count
      end

      test "l'année suit la date donnée : en août, c'est encore l'année qui finit" do
        create_classroom(school: @school, level: @sixth, name: "6ème 1", school_year: "2025-2026")
        create_classroom(school: @school, level: @sixth, name: "6ème 2", school_year: "2026-2027")
        teacher = create_teacher(school: @school)

        row = TeachingSelectionQuery.new.call(teacher_id: teacher.id, school_id: @school.id, today: Date.new(2026, 8, 31))

        assert_equal [ [ "6ème", [ "6ème 1" ] ] ], names(row)
      end

      test "la déclaration d'un autre enseignant ne compte pas ; une école sans classe donne une liste vide" do
        classroom = create_classroom(school: @school, level: @sixth, name: "6ème 1")
        create_teacher(school: @school, classrooms: [ classroom ])
        teacher = create_teacher(school: @school)

        assert_equal [ false ], TeachingSelectionQuery.new.call(teacher_id: teacher.id, school_id: @school.id)
                                                          .levels.flat_map(&:classrooms).map(&:declared)

        empty = create_school(name: "Collège Voltaire")
        row = TeachingSelectionQuery.new.call(teacher_id: teacher.id, school_id: empty.id)
        assert_equal [ "Collège Voltaire", [], 0 ], [ row.school_name, row.levels, row.declared_count ]
      end

      test "l'onboarding vient du profil, pas des classes déclarées" do
        classroom = create_classroom(school: @school, level: @sixth, name: "6ème 1")
        pending = create_teacher(school: @school, onboarded: false, classrooms: [ classroom ])
        done = create_teacher(school: @school)

        assert_not TeachingSelectionQuery.new.call(teacher_id: pending.id, school_id: @school.id).onboarded
        assert TeachingSelectionQuery.new.call(teacher_id: done.id, school_id: @school.id).onboarded
      end
    end
  end
end
