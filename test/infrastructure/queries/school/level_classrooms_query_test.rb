require "test_helper"

module Queries
  module School
    # CN-01, UDR-0046 : une ligne par niveau (par couple niveau/série au second cycle) avec le nombre de classes de
    # l'année, archivées comprises, et la dernière classe, celle que « − » retire.
    class LevelClassroomsQueryTest < ActiveSupport::TestCase
      YEAR = "2026-2027".freeze

      setup do
        @sixth = create_level(name: "6ème", position: 1, cycle: "first")
        @final = create_level(name: "Tle", position: 7)
        @second = create_level(name: "2nde", position: 5)
        @d = create_series(name: "D")
        @a1 = create_series(name: "A1")
        link_level_series(level: @final, series: @d)
        link_level_series(level: @final, series: @a1)
        @school = create_school(cycle: "both")
      end

      def block(school = @school) = LevelClassroomsQuery.new.call(public_id: school.public_id, school_year: YEAR)
      def rows(school = @school) = block(school).rows
      def summary(rows) = rows.map { [ it.key, it.label, it.count, it.last_classroom&.name, it.open ] }

      test "les couples ouverts dans l'ordre du référentiel, avec le nombre de classes de l'année et la dernière" do
        create_classroom(school: @school, level: @sixth, name: "6ème 2", school_year: YEAR)
        last = create_classroom(school: @school, level: @sixth, name: "6ème 10", school_year: YEAR)
        create_classroom(school: @school, level: @sixth, name: "6ème 11", school_year: "2025-2026")
        create_classroom(level: @sixth, name: "6ème 12", school_year: YEAR)
        create_classroom(school: @school, level: @final, series: @d, name: "Tle D 1", school_year: YEAR, status: "archived")

        result = rows

        assert_equal [ [ "6eme", "6ème", 2, "6ème 10", true ], [ "2nde", "2nde", 0, nil, true ],
                       [ "tle-a1", "Tle A1", 0, nil, true ], [ "tle-d", "Tle D", 1, "Tle D 1", true ] ], summary(result)
        assert_equal last.public_id, result.first.last_classroom.public_id
        assert_equal [ "6eme", nil ], [ result.first.level_slug, result.first.series_slug ]
        assert_equal [ "tle", "d" ], [ result.last.level_slug, result.last.series_slug ]
      end

      test "un collège ne voit que le premier cycle" do
        assert_equal [ "6eme" ], rows(create_school(cycle: "first")).map(&:key)
      end

      test "une classe d'un couple qui n'est plus ouvert a sa ligne, fermée : la somme reste le total de la fiche" do
        c = create_series(name: "C")
        create_classroom(school: @school, level: @final, series: c, name: "Tle C 1", school_year: YEAR)
        create_classroom(school: @school, level: @final, name: "Terminale", school_year: YEAR)

        assert_equal [ [ "6eme", "6ème", 0, nil, true ], [ "2nde", "2nde", 0, nil, true ], [ "tle", "Tle", 1, "Terminale", false ],
                       [ "tle-a1", "Tle A1", 0, nil, true ], [ "tle-c", "Tle C", 1, "Tle C 1", false ],
                       [ "tle-d", "Tle D", 0, nil, true ] ], summary(rows)
      end

      test "le bloc porte l'établissement et son statut, pour décider de « + »" do
        draft = create_school(status: "draft")

        assert_equal [ draft.public_id, "draft" ], [ block(draft).school_public_id, block(draft).school_status ]
      end

      test "un établissement inconnu donne nil" do
        assert_nil LevelClassroomsQuery.new.call(public_id: "inconnu")
      end
    end
  end
end
