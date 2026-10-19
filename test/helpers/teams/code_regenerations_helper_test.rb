require "test_helper"

# UDR-0104, UDR-0105: the filters of a mass regeneration read as the list shows them, and its report names its selection.
module Teams
  class CodeRegenerationsHelperTest < ActionView::TestCase
    Scope = Queries::School::CodeRegenerationPreviewQuery::Scope
    Report = Data.define(:kind, :details)

    def selection(**) = Dtos::School::SchoolSelection.from(**)

    test "the filters other than the DRENA read in the order of the list; a value outside its list is ignored" do
      assert_equal [ "Privé", "Premier cycle", "Brouillon", "« moderne »" ],
                   code_regeneration_filter_labels(selection(drena: "x", school_type: "private", cycle: "first", status: "draft", search: "moderne"))
      assert_equal [], code_regeneration_filter_labels(selection(school_type: "secret", cycle: "third", status: "gone"))
    end

    test "the selection of a report: a DRENA and its filters, one school, all the schools; the year of the links" do
      codes = Report.new(kind: "school_codes", details: { "selection" => { "drena" => "x", "cycle" => "both" } })
      links = Report.new(kind: "classroom_links", details: { "selection" => { "school" => "y", "school_year" => "2026-2027" } })

      assert_equal "Sélection : DRENA Abidjan 1 · Premier et second cycles",
                   code_regeneration_selection_label(codes, Scope.new(drena_name: "Abidjan 1", school_name: nil))
      assert_equal "Sélection : Lycée Moderne · année 2026-2027",
                   code_regeneration_selection_label(links, Scope.new(drena_name: nil, school_name: "Lycée Moderne"))
      assert_equal "Sélection : Tous les établissements · toutes les années",
                   code_regeneration_selection_label(Report.new(kind: "classroom_links", details: {}), Scope.new(drena_name: nil, school_name: nil))
    end
  end
end
