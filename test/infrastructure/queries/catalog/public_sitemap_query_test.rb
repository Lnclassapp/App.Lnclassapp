require "test_helper"

module Queries
  module Catalog
    # ADR-0099 §4.4 : les pages du catalogue qui ont au moins un cours publié, avec leur date, en trois requêtes.
    class PublicSitemapQueryTest < ActiveSupport::TestCase
      test "levels, level and series pairs and materials with a published course, in three queries" do
        referential = seed_referential
        tle = referential[:levels].fetch("tle")
        course = create_course(level: tle, material: referential[:materials].fetch("svt"), series: referential[:series].fetch("c"))
        create_course(level: referential[:levels].fetch("3eme"), material: referential[:materials].fetch("philosophie"), status: "draft")
        at = course.reload.updated_at

        result = assert_queries_count(3) { PublicSitemapQuery.new.call }

        assert_equal [ [ "tle", at ] ], result.levels
        assert_equal [ [ "tle", "c", at ] ], result.series
        assert_equal [ [ "svt", at ] ], result.materials
      end

      test "nothing published, nothing listed" do
        result = PublicSitemapQuery.new.call

        assert_equal [ [], [], [] ], [ result.levels, result.series, result.materials ]
      end
    end
  end
end
