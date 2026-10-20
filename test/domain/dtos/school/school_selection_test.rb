require "test_helper"

# ADR-0096 §4.2, §4.5: the selection of a mass regeneration is the filters of the list, or one school.
module Dtos
  module School
    class SchoolSelectionTest < ActiveSupport::TestCase
      test "blank values become nil and the others are squished" do
        selection = SchoolSelection.from({ drena: " abc ", school_type: "", cycle: nil, status: "active", search: "  lycée   moderne ",
                                           school: "  " })

        assert_equal [ "abc", nil, nil, "active", "lycée moderne", nil ], selection.deconstruct
      end

      test "string keys are read too, unknown keys and non-strings are ignored" do
        selection = SchoolSelection.from({ "drena" => "abc", "other" => "x", "status" => [ "active" ], "school_type" => { a: 1 } })

        assert_equal({ "drena" => "abc" }, selection.to_h)
      end

      test "an absent selection is all the schools" do
        assert_equal({}, SchoolSelection.from(nil).to_h)
        refute SchoolSelection.from(nil).scoped?
      end

      test "a too long search is cut, as the list would not find it anyway" do
        assert_equal SchoolSelection::SEARCH_MAX, SchoolSelection.from({ search: "a" * 500 }).search.length
      end

      test "a single DRENA or a single school is scoped: no number to type" do
        assert SchoolSelection.from({ drena: "abc" }).scoped?
        assert SchoolSelection.from({ school: "xyz" }).scoped?
        refute SchoolSelection.from({ status: "active", search: "lycée" }).scoped?
      end

      test "one school replaces the filters" do
        selection = SchoolSelection.from({ drena: "abc", status: "active", school: "xyz" })

        assert_equal({ "school" => "xyz" }, selection.to_h)
        assert_equal({}, selection.filters)
      end

      test "the filters are given as keywords for the list scope" do
        selection = SchoolSelection.from({ drena: "abc", search: "lycée" })

        assert_equal({ drena: "abc", school_type: nil, cycle: nil, status: nil, search: "lycée" }, selection.filters)
      end

      test "to_h then from gives back the same selection, as the report stores it" do
        selection = SchoolSelection.from({ drena: "abc", cycle: "first" })

        assert_equal selection, SchoolSelection.from(selection.to_h)
      end
    end
  end
end
