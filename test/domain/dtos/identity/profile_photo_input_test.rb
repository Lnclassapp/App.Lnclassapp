require "test_helper"

# PH-04, ADR-0060: the server trusts the bytes, not the name nor the announced type; it refuses what is not a small
# JPEG, PNG or WebP, and removes the shooting metadata of what it keeps.
module Dtos
  module Identity
    class ProfilePhotoInputTest < ActiveSupport::TestCase
      def input(name = nil, bytes: nil)
        bytes ||= file_fixture("photos/#{name}").binread if name
        ProfilePhotoInput.new(photo: bytes && StringIO.new(bytes))
      end

      def error(dto)
        assert_not dto.valid?
        dto.errors.details[:photo].first
      end

      test "a small JPEG, PNG or WebP is valid; its format, size and bytes are exposed" do
        { "photo.jpg" => "image/jpeg", "photo.png" => "image/png", "photo_lossy.webp" => "image/webp" }.each do |name, type|
          dto = input(name)

          assert dto.valid?, name
          assert_equal [ type, 64, 48 ], [ dto.content_type, dto.width, dto.height ], name
          assert_equal file_fixture("photos/#{name}").binread, dto.data, name
          assert_equal dto.data.bytesize, dto.byte_size
        end
      end

      test "the Exif of a photo is removed from the kept bytes" do
        dto = input("photo_exif.jpg")

        assert dto.valid?
        assert_not_includes dto.data, "PhoneMaker"
        assert_not Entities::Identity::ImageHeader.read(dto.data).metadata
      end

      # Challenge of PR #50: files posted directly, without the browser's crop.
      test "a truncated, header-only or corrupt image, or a JPEG with a stray byte, is unsupported" do
        %w[truncated.webp bomb_header.webp corrupt.webp bypass_exif.jpg].each do |name|
          assert_equal({ error: :unsupported }, error(input("hostile/#{name}")), name)
        end
      end

      test "a JPEG with fill bytes before its Exif is kept without its Exif nor its hidden camera name" do
        dto = input("hostile/bypass_fill.jpg")

        assert dto.valid?
        assert_not_includes dto.data, "Exif"
        assert_not_includes dto.data, "SECRETCAM"
      end

      test "the kept bytes are read again: if stripping ever left metadata, the image would be refused" do
        header = Entities::Identity::ImageHeader
        strip = header.method(:strip)
        header.define_singleton_method(:strip) { |bytes| bytes }
        assert_equal({ error: :unsupported }, error(input("photo_exif.jpg")))

        header.define_singleton_method(:strip) { |_| "damaged" }
        assert_equal({ error: :unsupported }, error(input("photo.jpg")))
      ensure
        header.define_singleton_method(:strip, strip)
      end

      test "no file: blank" do
        assert_equal({ error: :blank }, error(input))
      end

      test "a PDF, a text renamed .jpg or an empty file: unsupported, whatever its name" do
        [ input("document.pdf"), input(bytes: "not an image"), input(bytes: "") ].each do |dto|
          assert_equal({ error: :unsupported }, error(dto))
        end
      end

      test "more than 1 MB is refused before being read; more than 1024 px a side too" do
        heavy = StringIO.new("\xFF\xD8".b + ("\0" * Entities::Identity::ProfilePhoto::MAX_BYTES).b)
        def heavy.read(*) = raise("read before the size check")

        assert_equal({ error: :too_large, count: 1 }, error(ProfilePhotoInput.new(photo: heavy)))
        assert_equal({ error: :too_wide, count: 1024 }, error(input("too_wide.png")))
      end
    end
  end
end
