require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"

# ADR-0030, ADR-0058: the classrooms of a school, a pure function of the referential and of the barème it is given.
module Entities
  module Classroom
    class DefaultClassroomPlanTest < ActiveSupport::TestCase
      School = Data.define(:school_type, :cycle)
      Fixture = Catalog::TaxonomyFixture
      Entry = ClassroomPlan::Entry
      # The referential of the production: A1, A2, C and D linked to 2nde, 1ère and Tle.
      PRODUCTION_PAIRS = { "2nde" => %w[a1 a2 c d], "1ere" => %w[a1 a2 c d], "tle" => %w[a1 a2 c d] }.freeze

      def rows_for(school_type, cycle = "both", lookup: Fixture.lookup, plan: Fixture.plan(lookup))
        DefaultClassroomPlan.rows_for(school: School.new(school_type:, cycle:), lookup:, plan:)
      end

      # The barème of the fixture, with some entries replaced or removed (count nil).
      def plan_with(lookup, changes)
        entries = Fixture.plan(lookup).entries.reject { changes.key?([ it.school_type, it.level_id, it.series_id ]) }
        added = changes.filter_map { |(school_type, level_id, series_id), count| Entry.new(school_type:, level_id:, series_id:, count:) if count }
        ClassroomPlan.new(entries: entries + added)
      end

      test "with the development referential: public lycée 77, private and mixed 38, collèges 28 and 12" do
        generation = rows_for("public")

        assert_equal 77, generation.rows.size
        assert_equal({ levels: [], series: [] }, generation.skipped)
        assert_equal 6, generation.rows.count { it[:name].start_with?("Tle D ") }
        assert_equal 12, generation.rows.count { it[:name].start_with?("2nde ") }
        assert_equal [ 38, 38, 28, 12, 12 ], [ rows_for("private"), rows_for("mixed"), rows_for("public", "first"),
                                              rows_for("private", "first"), rows_for("mixed", "first") ].map { it.rows.size }
      end

      test "with the production referential, the barème taken over gives 89, 44, 28 and 12, as the old constant" do
        lookup = Fixture.lookup(pairs: PRODUCTION_PAIRS)

        assert_equal [ 89, 44, 28, 12 ], [ %w[public both], %w[private both], %w[public first], %w[private first] ]
          .map { |type, cycle| rows_for(type, cycle, lookup:).rows.size }
      end

      test "a collège only gets the first cycle, and never counts the second as skipped" do
        generation = rows_for("public", "first", plan: ClassroomPlan.new(entries: Fixture.plan.entries.select { it.series_id.nil? }))

        assert_equal 28, generation.rows.size
        assert generation.rows.all? { it[:series_id].nil? && it[:level_id] <= 4 }
        assert_equal({ levels: [], series: [] }, generation.skipped)
      end

      test "names always spaced, tied to the level and the series" do
        rows = rows_for("public").rows

        assert_includes rows, { name: "6ème 1", level_id: 1, series_id: nil }
        assert_includes rows, { name: "Tle D 3", level_id: 7, series_id: 105 }
        assert_includes rows, { name: "1ère A1 2", level_id: 6, series_id: 102 }
        assert_equal rows.size, rows.map { it[:name] }.uniq.size
      end

      test "the generation follows the barème it is given: a changed count, and 0 gives no classroom and counts nothing" do
        lookup = Fixture.lookup
        plan = plan_with(lookup, { [ "public", 1, nil ] => 6, [ "public", 7, 105 ] => 0 })

        generation = rows_for("public", lookup:, plan:)

        assert_equal 77 + 2 - 6, generation.rows.size
        assert_includes generation.rows.map { it[:name] }, "6ème 6"
        assert_not(generation.rows.any? { it[:name].start_with?("Tle D") })
        assert_equal({ levels: [], series: [] }, generation.skipped)
      end

      test "a missing entry gives no classroom and is counted: level of the first cycle, or level/series pair" do
        lookup = Fixture.lookup(pairs: Fixture::PAIRS.merge("tle" => %w[a a1 a2 c d]))
        plan = plan_with(lookup, { [ "public", 2, nil ] => nil })

        generation = rows_for("public", lookup:, plan:)

        assert_equal({ levels: %w[5eme], series: %w[tle/a] }, generation.skipped)
        assert_equal 77 - 4, generation.rows.size
      end

      test "a level of the second cycle without linked series is skipped and counted, as before" do
        lookup = Fixture.lookup(pairs: Fixture::PAIRS.except("1ere"))

        generation = rows_for("public", lookup:)

        assert_equal({ levels: %w[1ere], series: [] }, generation.skipped)
        assert_equal 77 - 24, generation.rows.size
      end

      test "an empty referential or an empty barème: nothing to generate" do
        assert_equal [ [], { levels: [], series: [] } ], rows_for("public", lookup: Fixture.lookup(levels: [], pairs: {})).to_h.values
        assert_equal({ levels: %w[6eme 5eme 4eme 3eme], series: %w[2nde/a 2nde/c 1ere/a1 1ere/a2 1ere/c 1ere/d tle/a1 tle/a2 tle/c tle/d] },
                     rows_for("public", plan: ClassroomPlan.new(entries: [])).skipped)
      end

      test "the levels come by position, whatever the order of the referential" do
        levels = [ [ "5ème", "5eme", 2 ], [ "6ème", "6eme", 1 ] ].map.with_index(1) do |(name, slug, position), id|
          Catalog::Level.new(id:, name:, slug:, position:, cycle: "first")
        end
        lookup = Catalog::TaxonomyLookup.new(levels:, series: [], materials: [], pairs: [])
        plan = ClassroomPlan.new(entries: levels.map { Entry.new(school_type: "public", level_id: it.id, series_id: nil, count: 1) })

        assert_equal [ "6ème 1", "5ème 1" ], rows_for("public", lookup:, plan:).rows.map { it[:name] }
      end

      test "the sheet of the screen: one line per level of the first cycle and per linked pair, with both counts" do
        lookup = Fixture.lookup(pairs: Fixture::PAIRS.merge("tle" => %w[a a1 a2 c d]).except("1ere"))
        sheet = DefaultClassroomPlan.sheet(plan: Fixture.plan(lookup), lookup:)

        assert_equal [ "6ème", "5ème", "4ème", "3ème", "2nde A", "2nde C", "1ère", "Tle A", "Tle A1", "Tle A2", "Tle C", "Tle D" ],
                     sheet.lines.map(&:name)
        sixth, second_a, first = sheet.lines.values_at(0, 4, 6)
        assert_equal({ "public" => 4, "private" => 2 }, sixth.counts)
        assert_equal({ "public" => 6, "private" => 3 }, second_a.counts)
        assert_equal [ false, false, true ], [ sixth, second_a, first ].map(&:unlinked?)
        assert_equal({ "public" => nil, "private" => nil }, sheet.lines[7].counts)
        assert_equal [ true, false, false ], [ sheet.lines[7], sixth, first ].map(&:undefined?)
        assert_equal 1, sheet.undefined_count
        assert_equal({ "public" => { "first" => 28, "both" => 28 + 12 + 13 }, "private" => { "first" => 12, "both" => 12 + 6 + 8 } },
                     sheet.totals)
      end

      test "the key of a line: level slug, then series slug" do
        sheet = DefaultClassroomPlan.sheet(plan: Fixture.plan, lookup: Fixture.lookup)

        assert_equal %w[6eme 2nde_a tle_d], sheet.lines.values_at(0, 4, -1).map(&:key)
        assert_equal [ nil, "a", "d" ], sheet.lines.values_at(0, 4, -1).map(&:series_slug)
      end

      test "an empty referential gives an empty sheet with zero totals" do
        sheet = DefaultClassroomPlan.sheet(plan: ClassroomPlan.new(entries: []), lookup: Fixture.lookup(levels: [], pairs: {}))

        assert_empty sheet.lines
        assert_equal 0, sheet.undefined_count
        assert_equal({ "public" => { "first" => 0, "both" => 0 }, "private" => { "first" => 0, "both" => 0 } }, sheet.totals)
      end
    end
  end
end
