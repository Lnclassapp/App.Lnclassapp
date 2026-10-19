require "test_helper"

# ADR-0104 §4.1 : la vérification de l'image d'article, aux plafonds d'un contenu pédagogique (300 Ko, 1200 px). Le reste
# (formats, métadonnées) est éprouvé par Dtos::Communication::ArticleImageInputTest, sur le même code.
module Dtos
  module Shared
    class ContentImageInputTest < ActiveSupport::TestCase
      IMAGE = Entities::Shared::ContentImage

      def input(bytes) = ContentImageInput.new(file: StringIO.new(bytes))

      def error(dto)
        assert_not dto.valid?
        dto.errors.details[:file].first
      end

      def png(width, height)
        chunk = ->(type, data) { [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N") }
        rows = ("\0".b + ("\x80".b * 3 * width)) * height
        "\x89PNG\r\n\x1A\n".b + chunk.("IHDR".b, [ width, height, 8, 2, 0, 0, 0 ].pack("NNC5")) +
          chunk.("IDAT".b, Zlib::Deflate.deflate(rows)) + chunk.("IEND".b, "".b)
      end

      test "une petite image est admise, sans ses métadonnées" do
        dto = input(file_fixture("photos/photo_exif.jpg").binread)

        assert dto.valid?
        assert_equal "image/jpeg", dto.content_type
        assert_not_includes dto.data, "PhoneMaker"
      end

      test "au-delà de 300 Ko, l'image est refusée avant toute lecture, et la raison cite les Ko" do
        dto = input("\xFF\xD8".b + ("\0".b * (IMAGE::MAX_BYTES + 1)))

        assert_equal({ error: :too_heavy, count: 300 }, error(dto))
        assert_includes dto.errors[:file].first, "300 Ko"
      end

      test "1200 px de côté sont admis, 1201 refusés" do
        assert input(png(1200, 10)).valid?
        assert_equal({ error: :too_large, count: 1200 }, error(input(png(1201, 10))))
      end

      test "un SVG renommé en .png est refusé pour son format" do
        assert_equal({ error: :content_type }, error(input(%(<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>))))
      end

      test "l'image d'article garde ses propres plafonds" do
        assert Dtos::Communication::ArticleImageInput.new(file: StringIO.new(png(1600, 10))).valid?
      end
    end
  end
end
