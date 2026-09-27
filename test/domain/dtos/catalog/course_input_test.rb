require "test_helper"

module Dtos
  module Catalog
    class CourseInputTest < ActiveSupport::TestCase
      def input(**overrides)
        CourseInput.new(name: "Génétique et évolution", subtitle: "Du gène à l'espèce", level_slug: "tle",
                        series_slug: "d", material_slug: "svt", content: "<div><strong>ADN</strong></div>", **overrides)
      end

      test "un cours saisi complet est valide ; le nom garde sa casse, espaces normalisés" do
        course = input(name: "  les atouts   de la Côte d'Ivoire ", subtitle: "  Un   sous-titre ")

        assert course.valid?
        assert_equal "les atouts de la Côte d'Ivoire", course.name
        assert_equal "Un sous-titre", course.subtitle
        assert_equal [ "tle", "d", "svt" ], [ course.level_slug, course.series_slug, course.material_slug ]
      end

      test "le contenu est le HTML de l'éditeur, gardé tel quel en chaîne" do
        assert_equal "<div><strong>ADN</strong></div>", input.content
        assert_equal "", input(content: nil).content
      end

      test "série et sous-titre sont facultatifs : vides, ils valent nil" do
        course = input(series_slug: " ", subtitle: "")

        assert course.valid?
        assert_nil course.series_slug
        assert_nil course.subtitle
        assert_nil input(series_slug: nil, subtitle: nil).subtitle
      end

      test "nom, niveau et matière sont obligatoires" do
        course = input(name: "  ", level_slug: "", material_slug: nil)

        assert_not course.valid?
        assert course.errors.of_kind?(:name, :blank)
        assert course.errors.of_kind?(:level_slug, :blank)
        assert course.errors.of_kind?(:material_slug, :blank)
        assert_nil course.level_slug
      end

      test "le nom et le sous-titre suivent les bornes de l'entité" do
        assert input(name: "a" * Entities::Catalog::Course::NAME_MAX, subtitle: "b" * Entities::Catalog::Course::SUBTITLE_MAX).valid?
        assert input(name: "a" * 201).tap(&:validate).errors.of_kind?(:name, :too_long)
        assert input(subtitle: "b" * 151).tap(&:validate).errors.of_kind?(:subtitle, :too_long)
      end
    end
  end
end
