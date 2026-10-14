require "test_helper"

# ADR-0089 §4.5 : dans le texte d'une fiche, une image se cite par son sgid et se montre par son adresse Lnclass.
module Orm
  class EssentialImageTest < ActiveSupport::TestCase
    test "la pièce jointe porte l'adresse Lnclass de l'image et ses dimensions, et se rend par le partiel de lecture" do
      image = create_essential_image

      attributes = image.to_rich_text_attributes
      assert_equal [ "/images/fiches/#{image.public_id}", image.width, image.height ], attributes.values_at(:url, :width, :height)
      assert_equal "catalog/essentials/body_image", image.to_attachable_partial_path
      assert_nil image.to_trix_content_attachment_partial_path
    end
  end
end
