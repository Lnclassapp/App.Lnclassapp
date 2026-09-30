require "test_helper"

module Entities
  module Catalog
    class ImportErrorTest < ActiveSupport::TestCase
      test "une erreur localisée par son chemin JSON, avec ses paramètres" do
        error = ImportError.new(path: "schools[412].type", code: :invalid_value, params: { value: "privee" })

        assert_equal "invalid_value", error.code
        assert_equal({ value: "privee" }, error.params)
        assert_not error.blocking?
        assert_equal({}, ImportError.new(path: "$", code: "json_invalid").params)
      end

      test "les erreurs d'enveloppe rejettent tout le fichier" do
        assert ImportError.new(path: "$.version", code: "version_unsupported").blocking?
        assert_equal 21, ImportError::CODES.size # + national_code_taken (ADR-0063), taken et no_latin_character (ADR-0066), duplicate_in_files (ADR-0068)
      end

      # ADR-0066 : un nom de DRENA déjà pris sous un autre slug est une erreur de la ligne.
      test "un nom déjà pris est une erreur d'élément" do
        assert_not ImportError.new(path: "drenas[0].name", code: "taken").blocking?
        assert_not ImportError.new(path: "drenas[0].name", code: "no_latin_character").blocking?
      end

      # ADR-0068 : dans un envoi de plusieurs fichiers, l'erreur nomme son fichier ; sinon la forme d'avant est gardée.
      test "le fichier est facultatif, et absent de la forme écrite quand il est inconnu" do
        single = ImportError.new(path: "courses[1].material_name", code: "unknown_material")
        multiple = ImportError.new(path: "courses[0]", code: "duplicate_in_files", params: { other: "b.json" }, file: "a.json")

        assert_equal({ path: "courses[1].material_name", code: "unknown_material", params: {} }, single.to_h)
        assert_equal "a.json", multiple.to_h[:file]
        assert_not multiple.blocking?
      end

      test "un motif hors liste lève ArgumentError" do
        assert_raises(ArgumentError) { ImportError.new(path: "$", code: "oops") }
      end
    end
  end
end
