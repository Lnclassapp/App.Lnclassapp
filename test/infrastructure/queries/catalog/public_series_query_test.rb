require "test_helper"

module Queries
  module Catalog
    # UDR-0115 §3.1 : un couple niveau × série rattaché, ses cours propres et les cours communs du niveau, en trois requêtes.
    class PublicSeriesQueryTest < ActiveSupport::TestCase
      setup do
        @referential = seed_referential
        @tle = @referential[:levels].fetch("tle")
        @maths = @referential[:materials].fetch("mathematiques")
        @series = @referential[:series]
      end

      test "the courses of the series and the common ones, the other visible series, in three queries" do
        create_course(level: @tle, material: @maths, name: "Suites", series: @series.fetch("d"))
        create_course(level: @tle, material: @maths, name: "Matrices", series: @series.fetch("c"))
        create_course(level: @tle, material: @maths, name: "Logique")

        result = assert_queries_count(3) { PublicSeriesQuery.new.call(level_slug: "tle", series_slug: "d") }

        assert_equal [ PublicSeriesQuery::Named.new(slug: "tle", name: "Tle"), PublicSeriesQuery::Named.new(slug: "d", name: "D") ],
                     [ result.level, result.series ]
        assert_equal [ "Logique", "Suites" ], result.groups.sole.cards.map(&:name)
        assert_equal [ 2, true ], [ result.total_count, result.common ]
        assert_equal [ [ "a1", "A1" ], [ "a2", "A2" ], [ "c", "C" ] ], result.siblings
      end

      test "nil for a series not attached to the level, an unknown level or series" do
        assert_nil PublicSeriesQuery.new.call(level_slug: "6eme", series_slug: "d")
        assert_nil PublicSeriesQuery.new.call(level_slug: "tle", series_slug: "inconnue")
        assert_nil PublicSeriesQuery.new.call(level_slug: "inconnu", series_slug: "d")
      end

      test "a pair without course: no group, no sibling" do
        result = PublicSeriesQuery.new.call(level_slug: "tle", series_slug: "a1")

        assert_equal [ [], [], 0, false ], [ result.groups, result.siblings, result.total_count, result.common ]
      end
    end
  end
end
