require "test_helper"

# ADR-0089, UDR-0084 §3.1 : la modale de fiche montre, dans l'ordre du texte, les images de la fiche ou encore à personne,
# avec le texte saisi, sinon l'enregistré. Une image d'une autre fiche n'est pas montrée.
module Queries
  module Catalog
    class EssentialFormImagesQueryTest < ActiveSupport::TestCase
      def attachment(image) = %(<action-text-attachment sgid="#{image.attachable_sgid}"></action-text-attachment>)

      test "ordre du texte, alt saisi sinon enregistré, images d'une autre fiche écartées" do
        essential = create_essential
        own = create_essential_image(essential:, alt: "Enregistré")
        orphan = create_essential_image
        foreign = create_essential_image(essential: create_essential)
        content = attachment(orphan) + "<p>x</p>" + attachment(own) + attachment(foreign)

        rows = EssentialFormImagesQuery.new.call(content:, image_alts: { orphan.public_id => "Saisi" }, essential_slug: essential.slug)

        assert_equal [ [ orphan.public_id, "Saisi" ], [ own.public_id, "Enregistré" ] ], rows.map { [ it.public_id, it.alt ] }
        assert_equal [ "/images/fiches/#{orphan.public_id}", orphan.attachable_sgid ], [ rows.first.url, rows.first.sgid ]
      end

      test "sans pièce jointe d'image de fiche, aucune ligne" do
        assert_empty EssentialFormImagesQuery.new.call(content: "<p>Texte</p>")
        assert_empty EssentialFormImagesQuery.new.call(content: nil)
      end
    end
  end
end
