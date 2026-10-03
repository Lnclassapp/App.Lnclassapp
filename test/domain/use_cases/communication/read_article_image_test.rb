require "test_helper"

# ADR-0074 §4.4, BL-14 : l'image d'un article publié se lit par tous, en cache public ; celle d'un brouillon, d'un archivé
# ou pas encore rattachée ne se lit que par qui gère le blog, en cache privé ; pour tout autre, elle est introuvable.
module UseCases
  module Communication
    class ReadArticleImageTest < ActiveSupport::TestCase
      ImageState = Ports::Communication::ArticleImageStorePort::ImageState

      # Note chaque lecture du fichier : la règle de lecture passe avant, et le fichier n'est lu qu'à la demande.
      class FakeImageStore
        include Ports::Communication::ArticleImageStorePort

        attr_reader :downloads

        def initialize(images)
          @images = images
          @downloads = []
        end

        def find(public_id:) = @images[public_id]
        def download(public_id:) = (@downloads << public_id) && "octets #{public_id}"
      end

      setup do
        @store = FakeImageStore.new(%w[published draft archived].to_h { [ it, state(it) ] }.merge("orphan" => state(nil)))
      end

      def state(article_status) = ImageState.new(content_type: "image/webp", article_status:)
      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)
      def outsiders = [ nil, actor(:student), actor(:teacher), actor(:school_admin), actor(:team, "field") ]
      def managers = [ actor(:team, "admin"), actor(:team, "content") ]

      def read(public_id, actor:)
        ReadArticleImage.new(images: @store, policy: Policies::Communication::ReadArticlePolicy.new).call(actor:, public_id:)
      end

      test "BL-14 : l'image d'un article publié se lit par tous, visiteur compris, et se garde en cache public" do
        (outsiders + managers).each do |someone|
          result = read("published", actor: someone)

          assert result.success?, someone.inspect
          assert_equal [ "image/webp", true ], [ result.value.content_type, result.value.public ]
          assert_equal "octets published", result.value.data.call
        end
      end

      test "le fichier n'est lu qu'à la demande de l'appelant, jamais pour une image refusée" do
        image = read("published", actor: nil).value
        outsiders.each { read("draft", actor: it) }
        assert_empty @store.downloads

        image.data.call
        assert_equal [ "published" ], @store.downloads
      end

      test "BL-14 : brouillon, archivé, non rattachée : lisibles par qui gère le blog seulement, jamais en cache public" do
        managers.product(%w[draft archived orphan]).each do |someone, public_id|
          result = read(public_id, actor: someone)

          assert result.success?, "#{someone.team_role} #{public_id}"
          assert_not result.value.public
          assert_equal [ "image/webp", "octets #{public_id}" ], [ result.value.content_type, result.value.data.call ]
        end
      end

      test "BL-14 : pour qui ne gère pas, l'image d'un brouillon, d'un archivé ou non rattachée est introuvable, comme une inconnue" do
        outsiders.product(%w[draft archived orphan inconnue]).each do |someone, public_id|
          assert_equal :not_found, read(public_id, actor: someone).code, "#{someone.inspect} #{public_id}"
        end
        managers.each { assert_equal :not_found, read("inconnue", actor: it).code }
      end
    end
  end
end
