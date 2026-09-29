require "test_helper"

# UDR-0053 (amendment of 2026-09-29): a schema error of the import report reads as a sentence, never as the raw
# json_schemer keyword (« … (schema) »). The keyword stays in the report data; only its display is translated.
module Teams
  class ImportsHelperTest < ActionView::TestCase
    def error(code, params = {}) = Queries::Catalog::ImportReportQuery::ErrorRow.new(path: "drenas[0].code", code:, params:)

    test "an unknown key, a missing key and a wrong type each read as a sentence" do
      assert_equal "Clé inconnue : ce format ne la prévoit pas.", import_error_message(error("schema", "keyword" => "schema"))
      assert_equal "Clé obligatoire manquante.", import_error_message(error("schema", "keyword" => "required"))
      assert_equal "Valeur attendue : un texte.", import_error_message(error("schema", "keyword" => "string"))
      assert_equal "Valeur attendue : une liste.", import_error_message(error("schema", "keyword" => "array"))
      assert_equal "Valeur attendue : un objet.", import_error_message(error("schema", "keyword" => "object"))
    end

    test "a keyword without its own sentence falls back to the generic one, never to the raw keyword" do
      message = import_error_message(error("schema", "keyword" => "uniqueItems"))

      assert_equal "Valeur non conforme au format attendu.", message
      assert_not_includes message, "uniqueItems"
      assert_equal "Valeur non conforme au format attendu.", import_error_message(error("schema"))
    end

    # A file of another import kind names that kind, so the team knows which button to use.
    test "a file of another import kind says which kind it is and what this import expects" do
      schools_in_drenas = error("format_mismatch", "expected" => "lnclass.drenas", "received" => "lnclass.schools")

      assert_equal "Ce fichier est un import « Établissements » (format lnclass.schools), pas un import « DRENA » " \
                   "(format lnclass.drenas) : téléversez-le depuis l'import « Établissements ».", import_error_message(schools_in_drenas)
    end

    test "an unknown or missing received format keeps the generic message" do
      generic = "Le format du fichier ne correspond pas à ce type d'import (attendu : lnclass.drenas)."

      assert_equal generic, import_error_message(error("format_mismatch", "expected" => "lnclass.drenas", "received" => "autre.chose"))
      assert_equal generic, import_error_message(error("format_mismatch", "expected" => "lnclass.drenas"))
    end

    test "any other code keeps its message and its parameters" do
      assert_equal "Valeur obligatoire manquante.", import_error_message(error("blank"))
      assert_equal "Le fichier contient 501 éléments ; 500 au plus.",
                   import_error_message(error("too_many_roots", "max" => 500, "count" => 501))
    end
  end
end
