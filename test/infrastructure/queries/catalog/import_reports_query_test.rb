require "test_helper"

module Queries
  module Catalog
    class ImportReportsQueryTest < ActiveSupport::TestCase
      setup do
        @author = create_team_member(first_name: "Awa", last_name: "Koné", second_factor: false)
        @query = ImportReportsQuery.new
      end

      test "liste les rapports du plus récent au plus ancien, avec le nom du fichier et l'auteur" do
        older = create_import_report(kind: "schools", status: "completed", imported_by: @author, created_at: 2.days.ago,
                                     total_count: 3, imported_count: 2, skipped_count: 1)
        older.source.attach(io: StringIO.new("{}"), filename: "ecoles.json", content_type: "application/json")
        newer = create_import_report(kind: "course_tree", imported_by: @author)

        rows = @query.call

        assert_equal [ newer.public_id, older.public_id ], rows.map(&:public_id)
        assert_equal [ "schools", "ecoles.json", "completed", 3, 2, 1, 0, "Awa Koné" ],
                     rows.last.to_h.values_at(:kind, :filename, :status, :total_count, :imported_count, :skipped_count,
                                              :error_count, :imported_by_name)
        assert_nil rows.first.filename
        assert_instance_of ImportReportsQuery::Row, rows.first
      end

      test "filtre par type et borne le nombre de lignes" do
        create_import_report(kind: "schools", status: "completed")
        create_import_report(kind: "exercises", status: "completed")
        create_import_report(kind: "exercises", status: "failed")

        assert_equal %w[exercises exercises], @query.call(kind: "exercises").map(&:kind)
        assert_equal 1, @query.call(limit: 1).size
      end
    end
  end
end
