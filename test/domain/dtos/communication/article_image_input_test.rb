require "test_helper"

# ADR-0074 §4.4, BL-12 : le serveur croit les octets, pas le nom ni le type annoncé ; il refuse ce qui n'est pas une image
# JPEG, PNG ou WebP fixe d'1 Mo et de 1600 px de côté au plus, avec sa raison, et retire les métadonnées de ce qu'il garde.
module Dtos
  module Communication
    class ArticleImageInputTest < ActiveSupport::TestCase
      IMAGE = Entities::Communication::ArticleImage

      def input(path = nil, bytes: nil)
        bytes ||= file_fixture(path).binread if path
        ArticleImageInput.new(file: bytes && StringIO.new(bytes))
      end

      def error(dto)
        assert_not dto.valid?
        dto.errors.details[:file].first
      end

      # Un PNG bien formé, gris uni, sans bibliothèque : de quoi éprouver le plafond des côtés.
      def png(width, height)
        chunk = ->(type, data) { [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N") }
        rows = ("\0".b + ("\x80".b * 3 * width)) * height
        "\x89PNG\r\n\x1A\n".b + chunk.("IHDR".b, [ width, height, 8, 2, 0, 0, 0 ].pack("NNC5")) +
          chunk.("IDAT".b, Zlib::Deflate.deflate(rows)) + chunk.("IEND".b, "".b)
      end

      test "une petite image JPEG, PNG ou WebP est admise ; son format, sa taille et ses octets sont exposés" do
        { "photos/photo.jpg" => "image/jpeg", "photos/photo.png" => "image/png", "photos/photo_lossy.webp" => "image/webp" }.each do |path, type|
          dto = input(path)

          assert dto.valid?, path
          assert_equal [ type, 64, 48 ], [ dto.content_type, dto.width, dto.height ], path
          assert_equal file_fixture(path).binread, dto.data, path
          assert_equal dto.data.bytesize, dto.byte_size
        end
      end

      test "BL-12 : l'Exif d'une photo est retiré des octets gardés" do
        dto = input("photos/photo_exif.jpg")

        assert dto.valid?
        assert_not_includes dto.data, "PhoneMaker"
        assert_not Entities::Shared::ImageHeader.read(dto.data).metadata
      end

      test "BL-12 : un GIF, un WebP animé, une photo HEIC sont refusés pour leur format" do
        heic = "\0\0\0\x18ftypheic".b + ("\0".b * 64)

        [ input("article_images/animation.gif"), input("article_images/animated.webp"), input(bytes: heic) ].each do |dto|
          assert_equal({ error: :content_type }, error(dto))
        end
      end

      test "BL-12 : un texte renommé .jpg, un fichier vide ou une image tronquée ne sont pas des images lisibles" do
        [ input("article_images/fake.jpg"), input(bytes: ""), input("photos/hostile/truncated.webp") ].each do |dto|
          assert_equal({ error: :unreadable }, error(dto))
        end
      end

      test "BL-12 : 1 Mo + 1 octet est refusé avant toute lecture ; plus de 1600 px de côté aussi" do
        heavy = StringIO.new("\xFF\xD8".b + ("\0" * (IMAGE::MAX_BYTES - 1)).b)
        def heavy.read(*) = raise("lu avant le contrôle du poids")

        assert_equal IMAGE::MAX_BYTES + 1, heavy.size
        assert_equal({ error: :too_heavy, count: 1 }, error(ArticleImageInput.new(file: heavy)))
        assert_equal({ error: :too_large, count: 1600 }, error(input(bytes: png(1601, 1))))
        assert_equal({ error: :too_large, count: 1600 }, error(input(bytes: png(1, 1601))))
        assert input(bytes: png(1600, 2)).valid?
      end

      test "les octets gardés sont relus : si le retrait laissait des métadonnées, l'image serait refusée" do
        header = Entities::Shared::ImageHeader
        strip = header.method(:strip)
        header.define_singleton_method(:strip) { |bytes| bytes }
        assert_equal({ error: :unreadable }, error(input("photos/photo_exif.jpg")))

        header.define_singleton_method(:strip) { |_| "abîmé" }
        assert_equal({ error: :unreadable }, error(input("photos/photo.jpg")))
      ensure
        header.define_singleton_method(:strip, strip)
      end

      test "sans fichier : blank" do
        assert_equal({ error: :blank }, error(input))
      end

      test "chaque raison a son message en français" do
        messages = { blank: {}, content_type: {}, unreadable: {}, too_heavy: { count: 1 }, too_large: { count: 1600 },
                     too_many: { count: 10 } }.map do |type, options|
          dto = ArticleImageInput.new
          dto.errors.add(:file, type, **options)
          dto.errors[:file].first
        end

        assert_equal [ "Choisissez une image.", "Ce format n'est pas accepté : JPEG, PNG ou WebP fixe seulement.",
                       "Ce fichier n'est pas une image lisible.", "L'image dépasse 1 Mo, même allégée.",
                       "L'image dépasse 1600 pixels de côté.", "L'article a déjà 10 images dans son texte." ], messages
      end
    end
  end
end
