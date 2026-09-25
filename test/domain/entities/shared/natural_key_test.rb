require "test_helper"

module Entities
  module Shared
    class NaturalKeyTest < ActiveSupport::TestCase
      test "squish, minuscules et sans accents" do
        assert_equal "lycee moderne", NaturalKey.normalize("Lycée  Moderne")
        assert_equal NaturalKey.normalize("lycée moderne"), NaturalKey.normalize(" LYCEE   Moderne ")
        assert_equal "genetique et heredite", NaturalKey.normalize("  Génétique   et HÉRÉDITÉ ")
        assert_equal "", NaturalKey.normalize(nil)
      end
    end
  end
end
