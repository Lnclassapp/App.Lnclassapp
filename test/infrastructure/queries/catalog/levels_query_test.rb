require "test_helper"

module Queries
  module Catalog
    class LevelsQueryTest < ActiveSupport::TestCase
      Row = LevelsQuery::Row

      test "aucun niveau : une liste vide" do
        assert_empty LevelsQuery.new.call
      end

      test "les niveaux par position, avec leurs séries par nom, leurs classes et leurs cours" do
        tle = create_level(name: "Tle", position: 7, cycle: "second")
        sixth = create_level(name: "6ème", position: 1, cycle: "first")
        link_level_series(level: tle, series: create_series(name: "D"))
        link_level_series(level: tle, series: create_series(name: "C"))
        2.times { create_classroom(level: tle) }
        create_course(level: tle)
        create_course(level: sixth)

        rows = LevelsQuery.new.call

        assert_equal [ Row.new(slug: "6eme", name: "6ème", position: 1, cycle: "first", series_names: [],
                               classrooms_count: 0, courses_count: 1, generates_classrooms: true),
                       Row.new(slug: "tle", name: "Tle", position: 7, cycle: "second", series_names: %w[C D],
                               classrooms_count: 2, courses_count: 1, generates_classrooms: true) ], rows
      end

      test "un niveau par son slug, ou rien" do
        level = create_level(name: "2nde", position: 5)
        link_level_series(level:, series: create_series(name: "A"))
        create_classroom(level:)

        assert_equal Row.new(slug: "2nde", name: "2nde", position: 5, cycle: "second", series_names: [ "A" ],
                             classrooms_count: 1, courses_count: 0, generates_classrooms: true),
                     LevelsQuery.new.find(slug: "2nde")
        assert_nil LevelsQuery.new.find(slug: "inconnu")
      end

      test "un niveau dont le code n'est pas une clé du plan de génération est signalé hors génération" do
        create_level(name: "Sixième", position: 1, cycle: "first")
        create_level(name: "1ère", position: 6)

        assert_equal({ "sixieme" => false, "1ere" => true }, LevelsQuery.new.call.to_h { [ it.slug, it.generates_classrooms ] })
      end

      test "les codes générés sont ceux du plan, public et privé réunis, sans liste recopiée" do
        plan = Entities::Classroom::DefaultClassroomPlan::PLAN

        assert_equal (plan.fetch("public").keys | plan.fetch("private").keys), LevelsQuery::GENERATED_SLUGS
        assert_equal %w[6eme 5eme 4eme 3eme 2nde 1ere tle], LevelsQuery::GENERATED_SLUGS
      end

      test "une seule requête par table, quel que soit le nombre de niveaux" do
        3.times { |index| link_level_series(level: create_level(position: index + 1)) }

        queries = count_queries { LevelsQuery.new.call }

        assert_equal 4, queries
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
