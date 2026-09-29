require "test_helper"

# ADR-0058: the barème, a value built from its entries; a missing entry is « non défini » (nil), never 0.
module Entities
  module Classroom
    class ClassroomPlanTest < ActiveSupport::TestCase
      Entry = ClassroomPlan::Entry

      setup do
        @plan = ClassroomPlan.new(entries: [ Entry.new(school_type: "public", level_id: 1, series_id: nil, count: 4),
                                             Entry.new(school_type: "private", level_id: 1, series_id: nil, count: 0),
                                             Entry.new(school_type: "public", level_id: 7, series_id: 105, count: 6) ])
      end

      test "the count of an entry, by type, level and series" do
        assert_equal 4, @plan.count(school_type: "public", level_id: 1)
        assert_equal 0, @plan.count(school_type: "private", level_id: 1, series_id: nil)
        assert_equal 6, @plan.count(school_type: "public", level_id: 7, series_id: 105)
      end

      test "a missing entry is nil, not zero" do
        assert_nil @plan.count(school_type: "public", level_id: 7, series_id: 104)
        assert_nil @plan.count(school_type: "private", level_id: 7, series_id: 105)
        assert_nil @plan.count(school_type: "public", level_id: 7)
      end

      test "a mixed school reads the private barème, as in ADR-0030" do
        assert_equal "public", ClassroomPlan.school_type_for("public")
        assert_equal "private", ClassroomPlan.school_type_for("private")
        assert_equal "private", ClassroomPlan.school_type_for("mixed")
        assert_equal 0, @plan.count(school_type: "mixed", level_id: 1)
      end

      test "the entries are kept, frozen, and the bounds are named" do
        assert_equal 3, @plan.entries.size
        assert_predicate @plan.entries, :frozen?
        assert_equal %w[public private], ClassroomPlan::SCHOOL_TYPES
        assert_equal 0..30, ClassroomPlan::COUNTS
        assert_empty ClassroomPlan.new(entries: []).entries
      end
    end
  end
end
