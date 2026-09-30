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
        report.update!(files: [ { "name" => "dabou.json", "byte_size" => 2, "status" => "read", "imported" => 1, "skipped" => 0, "errors" => 2 } ])

        row = ImportReportQuery.new.call(public_id: report.public_id)

        assert_equal [ "dabou.json", "Kam Kara", 3, { "classrooms" => 12 } ],
                     row.to_h.values_at(:filename, :imported_by_name, :processed_count, :details)
        assert_equal [ ImportReportQuery::ErrorRow.new(path: "schools[2].type", code: "invalid_value", params: { "value" => "rural" }, file: nil) ],
                     row.import_errors
        assert_equal [ 1, [ ImportReportQuery::FileRow.new(name: "dabou.json", status: "read", reason: nil, imported: 1, skipped: 0, errors: 2) ] ],
                     [ row.file_count, row.files ]
      end

      # ADR-0068 : plusieurs fichiers, un refusé avec son motif, une erreur qui nomme son fichier.
      test "relit le bilan de chaque fichier et le fichier de chaque erreur" do
        report = create_import_report(
          kind: "course_tree", status: "completed",
          import_errors: [ { "path" => "courses[0].name", "code" => "blank", "params" => {}, "file" => "b.json" } ],
          files: [ { "name" => "a.json", "byte_size" => 9, "status" => "read", "reason" => nil, "imported" => 2, "skipped" => 1, "errors" => 0 },
                   { "name" => "b.json", "byte_size" => 3, "status" => "rejected",
                     "reason" => { "code" => "format_mismatch", "params" => { "expected" => "lnclass.course-tree" } },
                     "imported" => 0, "skipped" => 0, "errors" => 0 } ]
        )

        row = ImportReportQuery.new.call(public_id: report.public_id)

        assert_equal [ "a.json", 2 ], [ row.filename, row.file_count ]
        assert_equal "b.json", row.import_errors.first.file
        assert_equal [ "rejected", "format_mismatch", { "expected" => "lnclass.course-tree" }, "$" ],
                     [ row.files.last.status, row.files.last.reason.code, row.files.last.reason.params, row.files.last.reason.path ]
      end

      test "un public_id inconnu donne nil" do
        assert_nil ImportReportQuery.new.call(public_id: "inconnu")
      end
    end
  end
end
