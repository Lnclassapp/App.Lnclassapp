require "test_helper"

module Dtos
  module Catalog
    class LevelInputTest < ActiveSupport::TestCase
      def errors_of(name: "Tle", position: 1, cycle: "second")
        LevelInput.new(name:, position:, cycle:).tap(&:validate).errors
      end

      test "un niveau saisi complet est valide, son nom débarrassé des espaces en trop" do
        input = LevelInput.new(name: "  6ème  ", position: "1", cycle: "first")

        assert input.valid?
        assert_equal "6ème", input.name
        assert_equal({ name: "6ème", position: 1, cycle: "first" }, input.level_attributes)
      end

      test "nom, position et cycle sont obligatoires" do
        input = LevelInput.new(name: nil, position: "", cycle: nil)

        assert_not input.valid?
        assert input.errors.of_kind?(:name, :blank)
        assert input.errors.of_kind?(:position, :not_a_number)
        assert input.errors.of_kind?(:cycle, :inclusion)
        assert_nil input.name
      end

      test "le nom compte 20 caractères au plus, le cycle est l'un des deux cycles" do
        assert LevelInput.new(name: "a" * 20, position: 1, cycle: "second").valid?
        assert errors_of(name: "a" * 21).of_kind?(:name, :too_long)
        assert errors_of(cycle: "both").of_kind?(:cycle, :inclusion)
      end

      test "la position est un nombre entier saisi, jamais un texte converti en zéro" do
        assert errors_of(position: "sept").of_kind?(:position, :not_a_number)
        assert errors_of(position: "1.5").of_kind?(:position, :not_an_integer)
        assert errors_of(position: LevelInput::POSITION_MAX + 1).of_kind?(:position, :less_than_or_equal_to)
        assert LevelInput.new(name: "Tle", position: LevelInput::POSITION_MAX, cycle: "second").valid?
      end

      test "le signe d'une position est laissé à l'entité, qui porte la règle métier" do
        assert LevelInput.new(name: "Tle", position: "-1", cycle: "second").valid?
      end
    end
  end
end
