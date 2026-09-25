require "test_helper"

module Dtos
  module Catalog
    class EssentialInputTest < ActiveSupport::TestCase
      def input(**overrides)
        EssentialInput.new(course_slug: "genetique", name: "  Brassage   génétique ", subtitle: " La méiose ",
                           content: "<div><strong>Retenir</strong><ul><li>Un point</li></ul></div>", **overrides)
      end

      def errors_of(**) = input(**).tap(&:validate).errors

      test "une saisie complète est valide ; les espaces sont resserrés, la casse du nom est gardée" do
        essential = input

        assert essential.valid?
        assert_equal "genetique", essential.course_slug
        assert_equal({ name: "Brassage génétique", subtitle: "La méiose",
                       content: "<div><strong>Retenir</strong><ul><li>Un point</li></ul></div>" },
                     essential.essential_attributes)
      end

      test "le nom est obligatoire et compte 150 caractères au plus, comme le sous-titre" do
        assert errors_of(name: nil).of_kind?(:name, :blank)
        assert errors_of(name: "   ").of_kind?(:name, :blank)
        assert errors_of(name: "a" * 151).of_kind?(:name, :too_long)
        assert errors_of(subtitle: "b" * 151).of_kind?(:subtitle, :too_long)
        assert input(name: "a" * 150, subtitle: "b" * 150).valid?
      end

      test "le sous-titre et le contenu sont facultatifs" do
        essential = input(subtitle: nil, content: nil)

        assert essential.valid?
        assert_equal({ name: "Brassage génétique", subtitle: "", content: "" }, essential.essential_attributes)
      end

      test "une pièce jointe ou une image, même envoyée hors de l'éditeur, est refusée : texte seul en V1" do
        [ '<action-text-attachment sgid="x"></action-text-attachment>',
          '<figure data-trix-attachment="{&quot;url&quot;:&quot;/a.png&quot;}"></figure>',
          '<p>Voir <IMG src="/rails/active_storage/blobs/a.png"></p>' ].each do |content|
          assert errors_of(content:).of_kind?(:content, :attachment), content
        end
        assert input(content: "<p>Une figure de style, une image mentale.</p>").valid?
      end

      test "les messages d'erreur viennent de la locale de l'écran" do
        assert_equal [ I18n.t("activemodel.errors.models.dtos/catalog/essential_input.attributes.content.attachment") ],
                     errors_of(content: "<img src='/a.png'>")[:content]
        assert_equal I18n.t("activemodel.attributes.dtos/catalog/essential_input.name"), EssentialInput.human_attribute_name(:name)
      end
    end
  end
end
