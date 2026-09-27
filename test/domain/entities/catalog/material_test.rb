require "test_helper"

module Entities
  module Catalog
    class MaterialTest < ActiveSupport::TestCase
      def build(**overrides) = Material.new(name: " SVT ", shortname: " SVT ", category: "science", **overrides)

      test "une matière complète est valide et garde sa casse" do
        assert build.valid?
        assert_equal "SVT", build.name
        assert_equal "SVT", build.shortname
      end

      test "la catégorie est obligatoire et fermée" do
        assert build(category: nil).tap(&:validate).errors.of_kind?(:category, :inclusion)
        assert build(category: "sport").invalid?
      end

      test "nom et abrégé sont obligatoires et bornés" do
        assert build(name: nil, shortname: nil).invalid?
        assert build(name: "a" * 41).invalid?
        assert build(shortname: "a" * 11).invalid?
      end
    end
  end
end
