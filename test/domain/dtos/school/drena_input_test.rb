require "test_helper"

module Dtos
  module School
    class DrenaInputTest < ActiveSupport::TestCase
      test "normalise les espaces sans changer la casse" do
        input = DrenaInput.new(name: "  Abidjan   1  PLATEAU ")

        assert input.valid?
        assert_equal "Abidjan 1 PLATEAU", input.name
      end

      test "exige un nom, même fait d'espaces" do
        [ nil, "", "   " ].each do |name|
          input = DrenaInput.new(name:)

          assert_not input.valid?
          assert input.errors.of_kind?(:name, :blank), name.inspect
          assert_nil input.name
        end
      end

      test "limite le nom à 80 caractères, espaces retirés" do
        assert DrenaInput.new(name: "a" * 80).valid?
        assert DrenaInput.new(name: " #{'a' * 80} ").valid?
        too_long = DrenaInput.new(name: "a" * 81)

        assert_not too_long.valid?
        assert too_long.errors.of_kind?(:name, :too_long)
      end
    end
  end
end
