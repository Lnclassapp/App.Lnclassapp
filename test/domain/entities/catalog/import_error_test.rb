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
        assert_equal 18, ImportError::CODES.size
      end

      # ADR-0055 : un nom de DRENA déjà pris sous un autre slug est une erreur de la ligne.
      test "un nom déjà pris est une erreur d'élément" do
        assert_not ImportError.new(path: "drenas[0].name", code: "taken").blocking?
      end

      test "un motif hors liste lève ArgumentError" do
        assert_raises(ArgumentError) { ImportError.new(path: "$", code: "oops") }
      end
    end
  end
end
