require "test_helper"

# ADR-0060: the rules of a profile photo — three formats, 1 MB, 1024 px a side.
module Entities
  module Identity
    class ProfilePhotoTest < ActiveSupport::TestCase
      test "three formats, each with its content type, 1 MB and 1024 px at most" do
        assert_equal({ jpeg: "image/jpeg", png: "image/png", webp: "image/webp" }, ProfilePhoto::CONTENT_TYPES)
        assert_equal 1_048_576, ProfilePhoto::MAX_BYTES
        assert_equal 1, ProfilePhoto::MAX_MEGABYTES
        assert_equal 1024, ProfilePhoto::MAX_SIDE
      end
    end
  end
end
