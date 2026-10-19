require "test_helper"

# ADR-0105 §4.1 : plafonds d'une image de fiche ou de question ; un texte de remplacement fait d'espaces n'en est pas un.
module Entities
  module Shared
    class ContentImageTest < ActiveSupport::TestCase
      test "plafonds" do
        assert_equal [ 307_200, 1200, 30, 150 ], [ ContentImage::MAX_BYTES, ContentImage::MAX_SIDE, ContentImage::MAX_PER_ESSENTIAL, ContentImage::ALT_MAX ]
        assert_equal %w[image/jpeg image/png image/webp], ContentImage::CONTENT_TYPES
      end

      test "alt?" do
        assert ContentImage.new(public_id: "p", alt: "Une pile").alt?
        assert_not ContentImage.new(public_id: "p", alt: "  ").alt?
        assert_not ContentImage.new(public_id: "p").alt?
      end
    end
  end
end
