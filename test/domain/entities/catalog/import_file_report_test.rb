require "test_helper"

module Entities
  module Catalog
    # ADR-0068 : le bilan d'un fichier dans un rapport d'import.
    class ImportFileReportTest < ActiveSupport::TestCase
      test "un fichier en attente n'a ni motif ni compteur" do
        file = ImportFileReport.new(name: "a.json", byte_size: 12)

        assert_equal [ "pending", nil, 0, 0, 0 ], [ file.status, file.reason, file.imported, file.skipped, file.errors ]
        assert_not file.rejected?
      end

      test "un fichier refusé porte son motif" do
        reason = ImportError.new(path: "$", code: "json_invalid")
        file = ImportFileReport.new(name: "a.json", byte_size: 12, status: "rejected", reason:)

        assert file.rejected?
        assert_equal "json_invalid", file.reason.code
      end

      test "un statut hors liste lève ArgumentError" do
        assert_raises(ArgumentError) { ImportFileReport.new(name: "a.json", byte_size: 1, status: "done") }
      end

      test "deux fichiers du même nom restent distincts, numérotés dans l'ordre d'envoi" do
        assert_equal [ "cours.json", "a.json", "cours.json (2)", "cours.json (3)" ],
                     ImportFileReport.display_names(%w[cours.json a.json cours.json cours.json])
      end
    end
  end
end
