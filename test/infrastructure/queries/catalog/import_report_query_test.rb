require "test_helper"

module Queries
  module Catalog
    class ImportReportQueryTest < ActiveSupport::TestCase
      test "relit un rapport avec sa progression, ses détails et ses erreurs localisées" do
        report = create_import_report(
          status: "completed", total_count: 3, imported_count: 1, skipped_count: 1, error_count: 1, processed_count: 3,
          details: { "classrooms" => 12 },
          import_errors: [ { "path" => "schools[2].type", "code" => "invalid_value", "params" => { "value" => "rural" } } ],
          imported_by: create_team_member(first_name: "Kam", last_name: "Kara", second_factor: false)
        )
        report.source.attach(io: StringIO.new("{}"), filename: "dabou.json", content_type: "application/json")

        row = ImportReportQuery.new.call(public_id: report.public_id)

        assert_equal [ "dabou.json", "Kam Kara", 3, { "classrooms" => 12 } ],
                     row.to_h.values_at(:filename, :imported_by_name, :processed_count, :details)
        assert_equal [ ImportReportQuery::ErrorRow.new(path: "schools[2].type", code: "invalid_value", params: { "value" => "rural" }) ],
                     row.import_errors
      end

      test "un public_id inconnu donne nil" do
        assert_nil ImportReportQuery.new.call(public_id: "inconnu")
      end
    end
  end
end
