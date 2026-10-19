require "test_helper"

# ADR-0104 §4.1, §4.7 : l'équipe Administration et Contenu envoie une image de fiche ; le serveur croit les octets, refuse
# avec sa raison ce qui n'est pas une petite image (300 Ko, 1200 px), n'écrit alors rien, et refuse la 31e image d'une fiche.
module UseCases
  module Catalog
    class UploadEssentialImageTest < ActiveSupport::TestCase
      CAPS = Entities::Shared::ContentImage

      class FakeImageStore
        include Ports::Catalog::EssentialImageStorePort

        attr_reader :writes

        def initialize(counts)
          @counts = counts
          @writes = []
        end

        def count_for(essential_slug:) = @counts.fetch(essential_slug, 0)

        def store(data:, content_type:, width:, height:)
          @writes << { data:, content_type:, width:, height: }
          StoredImage.new(public_id: "img#{@writes.size}", sgid: "sgid#{@writes.size}", width:, height:)
        end
      end

      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        def initialize(*slugs) = @slugs = slugs
        def find_by_slug(slug:) = (Entities::Catalog::Essential.new(slug:) if @slugs.include?(slug))
      end

      setup do
        @store = FakeImageStore.new("pleine" => CAPS::MAX_PER_ESSENTIAL, "presque" => CAPS::MAX_PER_ESSENTIAL - 1)
        @essentials = FakeEssentials.new("pleine", "presque")
      end

      def actor(role = :team, team_role = "content") = Entities::Identity::Actor.new(user_id: 7, role:, team_role:)

      def upload(bytes, actor: self.actor, essential_slug: nil)
        UploadEssentialImage.new(images: @store, essentials: @essentials, policy: Policies::Catalog::ManageContentImagesPolicy.new)
                            .call(actor:, dto: Dtos::Shared::ContentImageInput.new(file: bytes && StringIO.new(bytes)), essential_slug:)
      end

      def jpeg = file_fixture("photos/photo_exif.jpg").binread

      test "une image valide est stockée sans métadonnées, rattachée à aucune fiche" do
        result = upload(jpeg)

        assert result.success?
        assert_equal "img1", result.value.public_id
        assert_equal [ "image/jpeg", 64, 48 ], @store.writes.first.values_at(:content_type, :width, :height)
        assert_not_includes @store.writes.first[:data], "PhoneMaker"
      end

      test "admin et contenu envoient ; le terrain, l'enseignant, l'élève non, et rien n'est écrit" do
        assert upload(jpeg, actor: actor(:team, "admin")).success?
        [ actor(:team, "field"), actor(:teacher, nil), actor(:student, nil) ].each do |someone|
          assert_equal :forbidden, upload(jpeg, actor: someone).code, someone.inspect
        end
        assert_equal 1, @store.writes.size
      end

      test "un fichier trop lourd ou absent est refusé avec sa raison, rien n'est écrit" do
        heavy = upload("\xFF\xD8".b + ("\0".b * (CAPS::MAX_BYTES + 1)))

        assert_equal :invalid, heavy.code
        assert_equal [ "L'image dépasse 300 Ko, même allégée." ], heavy.errors[:file]
        assert_equal :invalid, upload(nil).code
        assert_empty @store.writes
      end

      test "la 31e image d'une fiche est refusée ; la 30e passe ; une fiche inconnue est introuvable" do
        full = upload(jpeg, essential_slug: "pleine")

        assert_equal :invalid, full.code
        assert_equal [ "30 images au plus par fiche." ], full.errors[:file]
        assert upload(jpeg, essential_slug: "presque").success?
        assert_equal :not_found, upload(jpeg, essential_slug: "inconnue").code
        assert_equal 1, @store.writes.size
      end
    end
  end
end
