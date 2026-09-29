require "test_helper"

module Entities
  module School
    class DrenaTest < ActiveSupport::TestCase
      test "normalise les espaces du nom et le limite à 80 caractères" do
        drena = Drena.new(name: "  Abidjan   1 ")

        assert drena.valid?
        assert_equal "Abidjan 1", drena.name
        assert Drena.new(name: "a" * 81).invalid?
        assert Drena.new(name: nil).tap(&:validate).errors.of_kind?(:name, :blank)
      end

      test "la clé est le slug figé, sinon celui du nom" do
        assert_equal "drena-abidjan-1", Drena.new(name: "Abidjan 1").key
        assert_equal "drena-abidjan-un", Drena.new(name: "Abidjan 1", slug: "drena-abidjan-un").key
      end

      # ADR-0055 : une seule règle, au formulaire comme à l'import.
      test "le slug est tiré du nom et préfixé par drena-" do
        assert_equal "drena-bouake-1", Drena.slug_for("Bouaké 1")
        assert_equal "drena-san-pedro", Drena.slug_for("  San-Pédro ")
        assert_equal "drena-grand-bassam", Drena.slug_for("Grand Bassam")
      end

      test "un nom sans lettre latine n'a pas de slug" do
        assert_nil Drena.slug_for("???")
        assert_nil Drena.slug_for("")
        assert_nil Drena.slug_for(nil)
      end
    end
  end
end
