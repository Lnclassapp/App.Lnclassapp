require "test_helper"

# ADR-0073 §4.4 : les plafonds d'une image d'article, lus par les vues, le JavaScript et le serveur.
module Entities
  module Communication
    class ArticleImageTest < ActiveSupport::TestCase
      test "JPEG, PNG ou WebP, 1 Mo, 1600 px de côté, 10 images dans le texte, 150 caractères de texte de remplacement" do
        assert_equal %w[image/jpeg image/png image/webp], ArticleImage::CONTENT_TYPES
        assert_equal [ 1, 1_048_576 ], [ ArticleImage::MAX_MEGABYTES, ArticleImage::MAX_BYTES ]
        assert_equal [ 1600, 10, 150 ], [ ArticleImage::MAX_SIDE, ArticleImage::MAX_PER_ARTICLE, ArticleImage::ALT_MAX ]
      end

      test "une image se compare par ses valeurs ; son texte de remplacement est saisi s'il n'est pas blanc" do
        image = ArticleImage.new(public_id: "image000000001", alt: "Un tableau noir", width: 1600, height: 900)

        assert_equal ArticleImage.new(public_id: "image000000001", alt: "Un tableau noir", width: 1600, height: 900), image
        assert image.alt?
        assert_not image.with(alt: "  ").alt?
        assert_not ArticleImage.new(public_id: "image000000001").alt?
      end
    end
  end
end
