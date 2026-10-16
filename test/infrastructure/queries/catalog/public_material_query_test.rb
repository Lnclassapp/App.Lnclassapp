require "test_helper"

module Queries
  module Catalog
    # UDR-0114 §3.1 : la page d'une matière, ses filtres, ses pages de 24 cartes, en un nombre fixe de requêtes.
    class PublicMaterialQueryTest < ActiveSupport::TestCase
      setup do
        @referential = seed_referential
        @levels = @referential[:levels]
        @maths = @referential[:materials].fetch("mathematiques")
        @d = @referential[:series].fetch("d")
      end

      def course(level, **attributes) = create_course(level: @levels.fetch(level), material: @maths, **attributes)
      def query(**filters) = PublicMaterialQuery.new.call(slug: "mathematiques", **filters)

      test "the levels with a course of the material, their counts, and the cards grouped by level, in three queries" do
        course("tle", name: "Suites")
        course("3eme", name: "Fractions")
        course("3eme", name: "Calcul littéral")
        course("3eme", name: "Brouillon", status: "draft")

        page = assert_queries_count(3) { query }

        assert_equal PublicCourses::Material.new(slug: "mathematiques", name: "Mathématiques", category: "science"), page.material
        assert_equal [ [ "3eme", "3ème", 2 ], [ "tle", "Tle", 1 ] ], page.levels
        assert_equal [ [ "3eme", 2, [ "Calcul littéral", "Fractions" ] ], [ "tle", 1, [ "Suites" ] ] ],
                     page.groups.map { [ it.level.slug, it.count, it.cards.map(&:name) ] }
        assert_equal [ nil, nil, 3, 1, 1 ], [ page.selected_level, page.selected_series, page.total_count, page.page, page.pages ]
      end

      test "a level, then a series: the series and the common courses, counted in one more query" do
        course("tle", name: "Suites", series: @d)
        course("tle", name: "Matrices", series: @referential[:series].fetch("c"))
        course("tle", name: "Logique")

        page = assert_queries_count(4) { query(level: "tle", series: "d") }
        level = query(level: "tle")
        assert_equal [ PublicMaterialQuery::Named.new(slug: "tle", name: "Tle"), 3 ], [ level.selected_level, level.total_count ]

        assert_equal [ "Logique", "Suites" ], page.groups.sole.cards.map(&:name)
        assert_equal [ PublicMaterialQuery::Named.new(slug: "d", name: "D"), 2 ], [ page.selected_series, page.total_count ]
      end

      test "24 cards a page; a page out of range, or forged, is the nearest one" do
        30.times { |index| course("tle", name: format("Cours %02d", index)) }

        assert_equal [ 24, 1, 2 ], query.then { [ it.groups.sole.cards.size, it.page, it.pages ] }
        assert_equal [ "Cours 24", 2 ], query(page: "7").then { [ it.groups.sole.cards.first.name, it.page ] }
        assert_equal 1, query(page: [ "2" ]).page
      end

      test "nil for an unknown material, an unknown or empty level, a series without level, unknown or not attached" do
        course("tle")

        assert_nil PublicMaterialQuery.new.call(slug: "inconnue")
        assert_nil query(level: "inconnu")
        assert_nil query(level: "3eme")
        assert_nil query(series: "d")
        assert_nil query(level: "tle", series: "inconnue")
        assert_nil query(level: "tle", series: "a")
      end

      test "a material without published course: no level, no group, one empty page" do
        page = query

        assert_equal [ [], [], 0, 1, 1 ], [ page.levels, page.groups, page.total_count, page.page, page.pages ]
      end
    end
  end
end
