require "test_helper"

module Queries
  module Catalog
    # UDR-0113 §3.2, §3.3, §3.6 : la liste des niveaux et l'Espace Niveau, en un nombre fixe de requêtes, sans brouillon.
    class PublicLevelsQueryTest < ActiveSupport::TestCase
      setup do
        @referential = seed_referential
        @tle = @referential[:levels].fetch("tle")
        @maths = @referential[:materials].fetch("mathematiques")
      end

      test "CC-01: the levels with a published course, by rank, with their count, cycle and visible series" do
        create_course(level: @referential[:levels].fetch("3eme"), material: @maths)
        create_course(level: @tle, material: @maths, series: @referential[:series].fetch("d"))
        create_course(level: @tle, material: @maths, status: "draft")
        create_course(level: @referential[:levels].fetch("5eme"), material: @maths, status: "archived")

        levels = PublicLevelsQuery.new.levels

        assert_equal [ [ "3eme", "3ème", "first", 1, [] ], [ "tle", "Tle", "second", 1, [ [ "d", "D" ] ] ] ],
                     levels.map { it.to_h.values }
      end

      test "CC-03: the level space, its visible series and its groups, in three queries" do
        create_course(level: @tle, material: @maths, name: "Suites")
        create_course(level: @tle, material: @referential[:materials].fetch("svt"), name: "Génétique")
        create_course(level: @referential[:levels].fetch("1ere"), material: @maths, name: "Dérivées")

        space = assert_queries_count(3) { PublicLevelsQuery.new.space(slug: "tle") }

        assert_equal [ "tle", "Tle", 2 ], [ space.slug, space.name, space.total_count ]
        assert_equal %w[a1 a2 c d], space.series.map(&:first)
        assert_equal [ [ "mathematiques", [ "Suites" ] ], [ "svt", [ "Génétique" ] ] ],
                     space.groups.map { [ it.material.slug, it.cards.map(&:name) ] }
      end

      test "an unknown level gives nil, a level without course an empty space" do
        assert_nil PublicLevelsQuery.new.space(slug: "inconnu")

        space = PublicLevelsQuery.new.space(slug: "5eme")
        assert_equal [ [], [], 0 ], [ space.series, space.groups, space.total_count ]
      end
    end
  end
end
