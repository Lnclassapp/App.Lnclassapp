require "test_helper"

# ADR-0104 §4.5 : une image de fiche se lit sous la règle de lecture de sa fiche. Fiche et cours publiés : tout connecté,
# en cache navigateur ; brouillon, archivée ou image pas encore rattachée : l'équipe seulement, jamais gardée ; sinon
# introuvable. Le fichier n'est lu qu'à la demande.
module UseCases
  module Catalog
    class ReadEssentialImageTest < ActiveSupport::TestCase
      ImageState = Ports::Catalog::EssentialImageStorePort::ImageState

      class FakeImageStore
        include Ports::Catalog::EssentialImageStorePort

        attr_reader :downloads

        def initialize(images)
          @images = images
          @downloads = []
        end

        def find(public_id:) = @images[public_id]
        def download(public_id:) = (@downloads << public_id) && "octets #{public_id}"
      end

      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        def initialize(essentials) = @essentials = essentials
        def find_by_slug(slug:) = @essentials[slug]
      end

      setup do
        essentials = {
          "publiee" => essential("published", "published"), "brouillon" => essential("draft", "published"),
          "cours-brouillon" => essential("published", "draft"), "archivee" => essential("archived", "published")
        }
        @store = FakeImageStore.new(essentials.keys.to_h { [ it, ImageState.new(content_type: "image/webp", essential_slug: it) ] }
                                             .merge("orpheline" => ImageState.new(content_type: "image/png", essential_slug: nil),
                                                    "fiche-disparue" => ImageState.new(content_type: "image/png", essential_slug: "x")))
        @essentials = FakeEssentials.new(essentials)
      end

      def essential(status, course_status) = Entities::Catalog::Essential.new(status:, course_status:, course_id: 4)
      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)
      def readers = [ actor(:student), actor(:teacher), actor(:school_admin) ]
      def team = [ actor(:team, "admin"), actor(:team, "content"), actor(:team, "field") ]

      def read(public_id, actor:)
        ReadEssentialImage.new(images: @store, essentials: @essentials, policy: Policies::Catalog::ReadPublishedPolicy.new)
                          .call(actor:, public_id:)
      end

      test "l'image d'une fiche publiée d'un cours publié se lit par tout connecté, gardée par le navigateur, avec son cours" do
        (readers + team).each do |someone|
          result = read("publiee", actor: someone)

          assert result.success?, someone.inspect
          assert_equal [ "image/webp", true, 4 ], [ result.value.content_type, result.value.public, result.value.course_id ]
          assert_equal "octets publiee", result.value.data.call
        end
      end

      test "brouillon, cours en brouillon, archivée : l'équipe seulement, jamais gardée ; les autres ne la trouvent pas" do
        %w[brouillon cours-brouillon archivee].each do |public_id|
          team.each do |someone|
            result = read(public_id, actor: someone)
            assert result.success?
            assert_not result.value.public
          end
          readers.each { assert_equal :not_found, read(public_id, actor: it).code, "#{it.role} #{public_id}" }
        end
      end

      test "une image pas encore rattachée ne se lit que par qui gère le contenu" do
        [ actor(:team, "admin"), actor(:team, "content") ].each do |someone|
          result = read("orpheline", actor: someone)
          assert_equal [ "image/png", false, nil ], [ result.value.content_type, result.value.public, result.value.course_id ]
        end
        (readers + [ actor(:team, "field") ]).each { assert_equal :not_found, read("orpheline", actor: it).code }
      end

      test "inconnue, fiche disparue ou visiteur : introuvable ; le fichier n'est jamais lu pour un refus" do
        assert_equal :not_found, read("inconnue", actor: actor(:team, "admin")).code
        assert_equal :not_found, read("fiche-disparue", actor: actor(:team, "admin")).code
        assert_equal :not_found, read("publiee", actor: nil).code
        readers.each { read("brouillon", actor: it) }

        assert_empty @store.downloads
      end
    end
  end
end
