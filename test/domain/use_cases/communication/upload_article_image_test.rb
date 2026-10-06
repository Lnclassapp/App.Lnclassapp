require "test_helper"

# ADR-0074 §4.4, BL-08, BL-12 : l'équipe Administration et Contenu envoie une image d'article ; le serveur croit les octets,
# refuse avec sa raison ce qui n'est pas une petite image JPEG, PNG ou WebP fixe, et n'écrit alors rien ; avec un article,
# il refuse la onzième image de son texte.
module UseCases
  module Communication
    class UploadArticleImageTest < ActiveSupport::TestCase
      IMAGE = Entities::Communication::ArticleImage

      class FakeImageStore
        include Ports::Communication::ArticleImageStorePort

        attr_reader :writes

        def initialize = @writes = []

        def store(data:, content_type:, width:, height:)
          @writes << { data:, content_type:, width:, height: }
          StoredImage.new(public_id: "img#{@writes.size}", sgid: "sgid#{@writes.size}", width:, height:)
        end
      end

      class FakeArticles
        include Ports::Communication::ArticleRepositoryPort

        def initialize(*articles) = @articles = articles.index_by(&:public_id)
        def find_by_public_id(public_id:) = @articles[public_id]
      end

      setup do
        @store = FakeImageStore.new
        @articles = FakeArticles.new(article("full", images: 10), article("nine", images: 9))
      end

      def actor(role = :team, team_role = "content") = Entities::Identity::Actor.new(user_id: 7, role:, team_role:)

      def article(public_id, images:)
        Entities::Communication::Article.new(public_id:, status: "draft",
                                             images: Array.new(images) { IMAGE.new(public_id: "#{public_id}#{it}") })
      end

      def file(path = nil, bytes: nil)
        bytes ||= file_fixture(path).binread if path
        bytes && StringIO.new(bytes)
      end

      # Un PNG bien formé, gris uni, sans bibliothèque : de quoi éprouver le plafond des côtés.
      def png(width, height)
        chunk = ->(type, data) { [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N") }
        rows = ("\0".b + ("\x80".b * 3 * width)) * height
        "\x89PNG\r\n\x1A\n".b + chunk.("IHDR".b, [ width, height, 8, 2, 0, 0, 0 ].pack("NNC5")) +
          chunk.("IDAT".b, Zlib::Deflate.deflate(rows)) + chunk.("IEND".b, "".b)
      end

      def upload(file, actor: self.actor, article_public_id: nil)
        UploadArticleImage.new(images: @store, articles: @articles, policy: Policies::Communication::ManageArticlesPolicy.new)
                          .call(actor:, dto: Dtos::Communication::ArticleImageInput.new(file:), article_public_id:)
      end

      test "une image vérifiée est stockée sans ses métadonnées, rattachée à aucun article ; le résultat porte son adresse" do
        result = upload(file("photos/photo_exif.jpg"))

        assert result.success?
        assert_equal Ports::Communication::ArticleImageStorePort::StoredImage.new(public_id: "img1", sgid: "sgid1", width: 64, height: 48),
                     result.value
        write = @store.writes.sole
        assert_equal [ "image/jpeg", 64, 48 ], write.values_at(:content_type, :width, :height)
        assert_not Entities::Shared::ImageHeader.read(write[:data]).metadata
      end

      test "l'équipe Administration envoie aussi ; PNG et WebP passent comme le JPEG" do
        assert upload(file("photos/photo.png"), actor: actor(:team, "admin")).success?
        assert upload(file("photos/photo_lossy.webp")).success?

        assert_equal %w[image/png image/webp], @store.writes.pluck(:content_type)
      end

      test "BL-12 : faux .jpg, GIF, WebP animé, 1 Mo + 1 octet, 1601 px, aucun fichier : refusés avec leur raison, rien de stocké" do
        oversized = "\xFF\xD8\xFF".b + ("\0".b * (IMAGE::MAX_BYTES - 2))
        wide = png(1601, 1)
        {
          file("article_images/fake.jpg") => "Ce fichier n'est pas une image lisible.",
          file("article_images/animation.gif") => "Ce format n'est pas accepté : JPEG, PNG ou WebP fixe seulement.",
          file("article_images/animated.webp") => "Ce format n'est pas accepté : JPEG, PNG ou WebP fixe seulement.",
          file(bytes: oversized) => "L'image dépasse 1 Mo, même allégée.",
          file(bytes: wide) => "L'image dépasse 1600 pixels de côté.",
          nil => "Choisissez une image."
        }.each do |sent, message|
          result = upload(sent)

          assert_equal :invalid, result.code, message
          assert_equal({ file: [ message ] }, result.errors)
        end
        assert_equal IMAGE::MAX_BYTES + 1, oversized.bytesize
        assert_empty @store.writes
      end

      test "BL-08 : le Terrain, l'enseignant, la direction, l'élève et le visiteur sont refusés avant toute lecture du fichier" do
        unread = Object.new # répondrait à read, rewind ou size par une erreur
        [ actor(:team, "field"), actor(:teacher, nil), actor(:school_admin, nil), actor(:student, nil), nil ].each do |someone|
          assert_equal :forbidden, upload(unread, actor: someone).code, someone.inspect
        end
        assert_empty @store.writes
      end

      test "avec un article : la dixième image de son texte passe, la onzième est refusée, rien de stocké" do
        assert upload(file("photos/photo.jpg"), article_public_id: "nine").success?

        result = upload(file("photos/photo.jpg"), article_public_id: "full")

        assert_equal :invalid, result.code
        assert_equal({ file: [ "L'article a déjà 10 images dans son texte." ] }, result.errors)
        assert_equal 1, @store.writes.size
      end

      test "un article inconnu est introuvable, et rien n'est stocké" do
        assert_equal :not_found, upload(file("photos/photo.jpg"), article_public_id: "inconnu").code
        assert_empty @store.writes
      end
    end
  end
end
