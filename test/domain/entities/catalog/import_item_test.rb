require "test_helper"

module Entities
  module Catalog
    class ImportItemTest < ActiveSupport::TestCase
      test "valide sans erreur, avec sa clé et son plan" do
        item = ImportItem.new(path: "schools[0]", key: [ 1, "lycee moderne" ], plan: { name: "Lycée Moderne" })

        assert item.valid?
        assert_empty item.errors
      end

      test "invalide dès une erreur" do
        error = ImportError.new(path: "schools[1].name", code: "blank")

        assert_not ImportItem.new(path: "schools[1]", errors: [ error ]).valid?
        assert_nil ImportItem.new(path: "schools[1]", errors: [ error ]).plan
      end
    end
  end
end
