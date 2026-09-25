require "test_helper"

module Dtos
  module Catalog
    class MaterialInputTest < ActiveSupport::TestCase
      def input(**overrides) = MaterialInput.new(name: " Sciences  de la Vie ", shortname: " SVT ", category: "science", **overrides)

      test "une saisie complète est valide ; les espaces sont resserrés, la casse est gardée" do
        material = input

        assert material.valid?
        assert_equal({ name: "Sciences de la Vie", shortname: "SVT", category: "science" }, material.to_h)
      end

      test "la catégorie est obligatoire, et seulement parmi les catégories de la matière" do
        assert input(category: nil).tap(&:validate).errors.of_kind?(:category, :inclusion)
        assert input(category: "").tap(&:validate).errors.of_kind?(:category, :inclusion)
        assert input(category: "sport").tap(&:validate).errors.of_kind?(:category, :inclusion)
        Entities::Catalog::Material::CATEGORIES.each { |category| assert input(category:).valid? }
      end

      test "le nom compte 40 caractères au plus, l'abrégé 10, et les deux sont obligatoires" do
        assert input(name: "a" * 40, shortname: "b" * 10).valid?
        assert input(name: "a" * 41).tap(&:validate).errors.of_kind?(:name, :too_long)
        assert input(shortname: "b" * 11).tap(&:validate).errors.of_kind?(:shortname, :too_long)
        assert input(name: nil).tap(&:validate).errors.of_kind?(:name, :blank)
        assert input(shortname: "   ").tap(&:validate).errors.of_kind?(:shortname, :blank)
      end

      test "les messages d'erreur viennent de la locale de l'écran" do
        material = input(name: "", category: nil).tap(&:validate)

        assert_equal [ I18n.t("activemodel.errors.models.dtos/catalog/material_input.attributes.name.blank") ], material.errors[:name]
        assert_equal [ I18n.t("activemodel.errors.models.dtos/catalog/material_input.attributes.category.inclusion") ],
                     material.errors[:category]
      end
    end
  end
end
