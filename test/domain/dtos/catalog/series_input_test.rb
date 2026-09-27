require "test_helper"

module Dtos
  module Catalog
    class SeriesInputTest < ActiveSupport::TestCase
      test "normalise les espaces sans changer la casse" do
        input = SeriesInput.new(name: "  A1   bis ")

        assert input.valid?
        assert_equal "A1 bis", input.name
      end

      test "exige un nom : absent, il vaut une chaîne vide" do
        input = SeriesInput.new(name: nil)

        assert_not input.valid?
        assert input.errors.of_kind?(:name, :blank)
        assert_equal "", input.name
        assert SeriesInput.new(name: "   ").invalid?
      end

      test "10 caractères au plus, comme la colonne et l'entité" do
        assert SeriesInput.new(name: "a" * 10).valid?

        input = SeriesInput.new(name: "a" * 11)
        assert_not input.valid?
        assert input.errors.of_kind?(:name, :too_long)
      end
    end
  end
end
