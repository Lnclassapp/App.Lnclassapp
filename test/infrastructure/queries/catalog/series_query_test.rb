require "test_helper"

module Queries
  module Catalog
    class SeriesQueryTest < ActiveSupport::TestCase
      setup do
        @second = create_level(name: "2nde", position: 5)
        @tle = create_level(name: "Tle", position: 7)
        @first = create_level(name: "1ère", position: 6)
        @d = create_series(name: "D")
        @a = create_series(name: "A")
        @c = create_series(name: "C")
        [ @tle, @first ].each { link_level_series(level: it, series: @d) }
        link_level_series(level: @second, series: @c)
        2.times { create_classroom(level: @tle, series: @d) }
        create_course(level: @first, series: @d)
        create_classroom(level: @second, series: nil)
      end

      test "une ligne par série, triées par nom : niveaux liés par position, classes et cours qui la portent" do
        rows = SeriesQuery.new.call

        assert_equal %w[A C D], rows.map(&:name)
        assert_equal SeriesQuery::Row.new(slug: "d", name: "D", level_names: %w[1ère Tle], classrooms_count: 2, courses_count: 1),
                     rows.last
        assert_equal SeriesQuery::Row.new(slug: "a", name: "A", level_names: [], classrooms_count: 0, courses_count: 0), rows.first
      end

      test "find renvoie la ligne d'une série par son slug, nil si elle n'existe pas" do
        assert_equal [ "c", [ "2nde" ] ], SeriesQuery.new.find(slug: "c").then { [ it.slug, it.level_names ] }
        assert_nil SeriesQuery.new.find(slug: "inconnue")
      end

      test "la matrice croise les niveaux par position et les séries par nom ; chaque case sait si le couple est lié et utilisé" do
        matrix = SeriesQuery.new.matrix

        assert_equal %w[2nde 1ère Tle], matrix.levels.map(&:name)
        assert_equal %w[a c d], matrix.series.map(&:slug)
        assert_equal SeriesQuery::Cell.new(level_slug: "tle", level_name: "Tle", series_slug: "d", series_name: "D", linked: true, used: true),
                     matrix.cell(matrix.levels.last, matrix.series.last)
        assert_equal [ true, true ], matrix.cell(matrix.levels[1], matrix.series.last).then { [ it.linked, it.used ] }
        assert_equal [ true, false ], matrix.cell(matrix.levels.first, matrix.series[1]).then { [ it.linked, it.used ] }
        assert_equal [ false, false ], matrix.cell(matrix.levels.first, matrix.series.first).then { [ it.linked, it.used ] }
      end

      test "cell renvoie une seule case par les slugs, nil si le niveau ou la série n'existe pas" do
        query = SeriesQuery.new

        assert_equal SeriesQuery::Cell.new(level_slug: "2nde", level_name: "2nde", series_slug: "c", series_name: "C", linked: true, used: false),
                     query.cell(level_slug: "2nde", series_slug: "c")
        assert_not query.cell(level_slug: "tle", series_slug: "a").linked
        assert_nil query.cell(level_slug: "inconnu", series_slug: "c")
        assert_nil query.cell(level_slug: "tle", series_slug: "inconnue")
      end
    end
  end
end
