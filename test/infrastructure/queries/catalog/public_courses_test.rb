require "test_helper"

module Queries
  module Catalog
    # ADR-0099 §4.1, §4.2 : le socle des pages publiques. Un brouillon ou un archivé ne sort jamais de la portée, les
    # matières suivent le rang du programme, six cartes au plus par matière, et une série n'est visible qu'avec un cours.
    class PublicCoursesTest < ActiveSupport::TestCase
      setup do
        @tle = create_level(name: "Tle", position: 7)
        @maths = create_material(name: "Mathématiques")
        @philo = create_material(name: "Philosophie", category: "literature")
        @svt = create_material(name: "SVT")
      end

      test "CC-06: the scope reads published courses only, never a draft nor an archived one" do
        published = create_course(name: "Suites", level: @tle, material: @maths)
        create_course(name: "Intégrales", level: @tle, material: @maths, status: "draft")
        create_course(name: "Limites", level: @tle, material: @maths, status: "archived")

        assert_equal [ published.id ], PublicCourses.scope.pluck(:id)
        assert PublicCourses.any?
      end

      test "no published course: any? is false and no group" do
        create_course(level: @tle, material: @maths, status: "draft")

        assert_not PublicCourses.any?
        result = PublicCourses.groups_by_material(PublicCourses.scope)
        assert_equal [ [], 0, false ], [ result.groups, result.total_count, result.common ]
      end

      test "CC-03: groups follow the program rank of the materials, a material without rank last, by name" do
        create_course(name: "La conscience", level: @tle, material: @philo)
        create_course(name: "Génétique", level: @tle, material: @svt)
        create_course(name: "Suites", level: @tle, material: @maths)
        create_course(name: "Allemand 1", level: @tle, material: create_material(name: "Allemand", position: nil))

        groups = PublicCourses.groups_by_material(PublicCourses.scope).groups

        assert_equal %w[mathematiques svt philosophie allemand], groups.map { it.material.slug }
        assert_equal PublicCourses::Material.new(slug: "philosophie", name: "Philosophie", category: "literature"), groups[2].material
      end

      test "CC-04: six cards per material, by name, and the count of the whole material" do
        9.times { |index| create_course(name: "Cours #{index}", subtitle: "Description #{index}", level: @tle, material: @maths) }
        create_course(name: "Brouillon", level: @tle, material: @maths, status: "draft")

        result = PublicCourses.groups_by_material(PublicCourses.scope)
        group = result.groups.sole

        assert_equal [ 9, 9 ], [ group.count, result.total_count ]
        assert_equal (0..5).map { "Cours #{it}" }, group.cards.map(&:name)
        assert_equal PublicCourses::Card.new(slug: "cours-0", name: "Cours 0", subtitle: "Description 0",
                                             material_slug: "mathematiques", level_slug: "tle"), group.cards.first
      end

      test "common says whether the scope holds a course without series" do
        series = create_series(name: "D")
        create_course(name: "Suites", level: @tle, material: @maths, series:)

        assert_not PublicCourses.groups_by_material(PublicCourses.scope).common

        create_course(name: "La conscience", level: @tle, material: @philo)
        assert PublicCourses.groups_by_material(PublicCourses.scope).common
      end

      test "CC-05: a series is visible with a course of its own or a common one, never through a draft" do
        c, d, a1 = %w[C D A1].map { |name| create_series(name:).tap { link_level_series(level: @tle, series: it) } }
        create_course(name: "Suites", level: @tle, material: @maths, series: d)
        create_course(name: "Mécanique", level: @tle, material: @maths, series: c, status: "draft")
        create_series(name: "E").tap { create_course(name: "Hors niveau", level: @tle, material: @maths, series: it) }

        assert_equal [ [ "tle", "d", "D" ] ], PublicCourses.series_pairs.map { it.first(3) }

        common = create_course(name: "La conscience", level: @tle, material: @philo)
        common.update_columns(updated_at: Time.zone.local(2026, 10, 1, 8))
        pairs = PublicCourses.series_pairs(level_id: @tle.id)

        assert_equal [ "a1", "c", "d" ], pairs.map(&:second)
        assert_equal Time.zone.local(2026, 10, 1, 8), pairs.find { it.second == "a1" }.last
        assert_includes [ a1, c ].map(&:slug), pairs.first.second
      end

      test "series_pairs of one level leaves the other levels out" do
        other = create_level(name: "1ère", position: 6)
        link_level_series(level: other, series: create_series(name: "D")).then do |pair|
          create_course(level: other, material: @maths, series: pair.series)
        end

        assert_equal [], PublicCourses.series_pairs(level_id: @tle.id)
        assert_equal [ "1ere" ], PublicCourses.series_pairs.map(&:first)
      end
    end
  end
end
