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

      # ADR-0089 : une fiche accepte des images, pièces jointes de son contenu ; c'est le repository qui n'en garde que les
      # images de fiche admises (RichTextSanitizer), la saisie ne les filtre plus.
      test "une pièce jointe d'image passe la saisie ; les textes de remplacement sont resserrés et bornés à 150 caractères" do
        essential = input(content: '<action-text-attachment sgid="x"></action-text-attachment>',
                          image_alts: { "img1" => "  Une   pile ", img2: "", "img3" => "a" * 150 })

        assert essential.valid?
        assert_equal({ "img1" => "Une pile", "img2" => nil, "img3" => "a" * 150 }, essential.image_alts)
        assert_equal [ [ "img1", "Une pile" ], [ "img2", nil ] ], essential.images.first(2).map { [ it.public_id, it.alt ] }
        assert errors_of(image_alts: { "img4" => "a" * 151 }).of_kind?(:"image_alts.img4", :too_long)
        assert_empty input.images
      end

      test "les messages d'erreur viennent de la locale de l'écran" do
        assert_equal [ I18n.t("activemodel.errors.models.dtos/catalog/essential_input.attributes.name.taken") ],
                     input.tap { it.errors.add(:name, :taken) }.errors[:name]
        assert_equal I18n.t("activemodel.attributes.dtos/catalog/essential_input.name"), EssentialInput.human_attribute_name(:name)
      end
    end
  end
end
