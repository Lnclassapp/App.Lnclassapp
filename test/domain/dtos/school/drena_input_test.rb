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

      # DR-08 (ADR-0066) : sans lettre ni chiffre latin, le slug serait « drena » nu.
      test "refuse un nom sans lettre ni chiffre latin, avec le message de la locale" do
        [ "???", "π", "« — »" ].each do |name|
          input = DrenaInput.new(name:)

          assert_not input.valid?, name
          assert_equal [ :invalid ], input.errors.details[:name].pluck(:error), name
        end
        assert_equal [ "Le nom doit contenir au moins une lettre ou un chiffre latin." ],
                     DrenaInput.new(name: "???").tap(&:valid?).errors[:name]
        assert DrenaInput.new(name: "Bouaké 1").valid?
        assert DrenaInput.new(name: "1").valid?
      end

      test "un nom absent n'est signalé que vide, pas invalide" do
        input = DrenaInput.new(name: "  ")

        assert_not input.valid?
        assert_equal [ :blank ], input.errors.details[:name].pluck(:error)
      end
    end
  end
end
