require "test_helper"

module Repositories
  module Catalog
    class ImportSchemaValidatorTest < ActiveSupport::TestCase
      ROOT = Rails.root.join("test/fixtures/files/import_schemas")

      setup { @validator = ImportSchemaValidator.new(root: ROOT) }

      def document(schools) = { "format" => "lnclass.schools", "version" => 1, "schools" => schools }

      test "un document conforme ne donne aucune erreur" do
        assert_empty @validator.validate(format: "fake", version: 1, document: document([ { "name" => "Lycée A" } ]))
      end

      test "convertit chaque erreur en ImportError au chemin JSON du rapport" do
        errors = @validator.validate(format: "fake", version: 1, document: document([ { "name" => "A" }, {}, { "name" => 12 } ]))

        assert_equal [ [ "schools[1].name", "schema", { keyword: "required" } ], [ "schools[2].name", "schema", { keyword: "string" } ] ],
                     errors.map { [ it.path, it.code, it.params ] }
      end

      test "une clé manquante de l'enveloppe est notée à sa place" do
        errors = @validator.validate(format: "fake", version: 1, document: { "format" => "lnclass.schools", "version" => 1 })

        assert_equal [ "schools" ], errors.map(&:path)
      end

      test "une enveloppe qui n'est pas un objet est notée à la racine" do
        assert_equal [ "$" ], @validator.validate(format: "fake", version: 1, document: []).map(&:path)
      end

      test "traduit un pointeur JSON en chemin du rapport" do
        assert_equal "$", ImportSchemaValidator.json_path("")
        assert_equal "schools[12].type", ImportSchemaValidator.json_path("/schools/12/type")
        assert_equal "courses[0].essentials[3].a/b~c", ImportSchemaValidator.json_path("/courses/0/essentials/3/a~1b~0c")
      end

      test "lit config/schemas par défaut" do
        assert_equal Rails.root.join("config/schemas"), ImportSchemaValidator.new.root
      end
    end
  end
end
