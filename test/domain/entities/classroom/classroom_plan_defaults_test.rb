require "test_helper"

# D1 decided by the owner (2026-09-28), ADR-0058: a new line of the barème is filled with defaults, never overwritten.
module Entities
  module Classroom
    class ClassroomPlanDefaultsTest < ActiveSupport::TestCase
      Level = Catalog::Level
      Series = Catalog::Series
      Entry = ClassroomPlan::Entry

      def level(slug, cycle = "second", id: 7) = Level.new(id:, slug:, name: slug, cycle:)
      def series(slug, id: 105) = Series.new(id:, slug:, name: slug.upcase)

      test "2nde, 1ère and any other level of the second cycle: 6 public, 3 private per linked series" do
        %w[2nde 1ere terminale-pro].each do |slug|
          assert_equal({ "public" => 6, "private" => 3 }, ClassroomPlanDefaults.counts_for(level: level(slug), series: series("a")), slug)
        end
      end

      test "Tle: the counts of the old barème per series, 6 and 3 for any other series" do
        { "c" => [ 2, 1 ], "d" => [ 6, 3 ], "a1" => [ 3, 2 ], "a2" => [ 2, 2 ], "e" => [ 6, 3 ] }.each do |slug, (pub, priv)|
          assert_equal({ "public" => pub, "private" => priv }, ClassroomPlanDefaults.counts_for(level: level("tle"), series: series(slug)), slug)
        end
      end

      test "first cycle: 4 and 2 for 6ème and 5ème, 10 and 4 for 4ème and 3ème; no reliable rule otherwise" do
        assert_equal({ "public" => 4, "private" => 2 }, ClassroomPlanDefaults.counts_for(level: level("5eme", "first"), series: nil))
        assert_equal({ "public" => 10, "private" => 4 }, ClassroomPlanDefaults.counts_for(level: level("3eme", "first"), series: nil))
        assert_nil ClassroomPlanDefaults.counts_for(level: level("sixieme", "first"), series: nil)
        assert_nil ClassroomPlanDefaults.counts_for(level: level("tle"), series: nil)
      end

      test "the missing entries only: an existing count, even 0, is never overwritten" do
        plan = ClassroomPlan.new(entries: [ Entry.new(school_type: "private", level_id: 7, series_id: 105, count: 0) ])

        assert_equal [ Entry.new(school_type: "public", level_id: 7, series_id: 105, count: 6) ],
                     ClassroomPlanDefaults.missing_entries(plan:, level: level("tle"), series: series("d"))
        full = ClassroomPlan.new(entries: %w[public private].map { Entry.new(school_type: it, level_id: 7, series_id: 105, count: 1) })
        assert_empty ClassroomPlanDefaults.missing_entries(plan: full, level: level("tle"), series: series("d"))
        assert_empty ClassroomPlanDefaults.missing_entries(plan: ClassroomPlan.new(entries: []), level: level("autre", "first"), series: nil)
      end
    end
  end
end
