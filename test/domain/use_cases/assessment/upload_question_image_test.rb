require "test_helper"

# ADR-0089 §4.7 : l'équipe admin et contenu envoie l'image d'une question ; le serveur croit les octets, refuse avec sa
# raison ce qui n'est pas une image de 300 Ko et 1200 px au plus, et n'écrit alors rien.
module UseCases
  module Assessment
    class UploadQuestionImageTest < ActiveSupport::TestCase
      class FakeImageStore
        include Ports::Assessment::QuestionImageStorePort

        attr_reader :writes

        def initialize = @writes = []

        def store(data:, content_type:, width:, height:)
          @writes << { data:, content_type:, width:, height: }
          StoredImage.new(public_id: "img#{@writes.size}", width:, height:)
        end
      end

      setup { @store = FakeImageStore.new }

      def actor(role = :team, team_role = "content") = Entities::Identity::Actor.new(user_id: 7, role:, team_role:)

      def upload(file, actor: self.actor)
        UploadQuestionImage.new(images: @store, policy: Policies::Catalog::ManageContentPolicy.new)
                           .call(actor:, dto: Dtos::Shared::ContentImageInput.new(file:))
      end

      test "une petite image est stockée sans métadonnées, et son adresse rendue" do
        result = upload(StringIO.new(file_fixture("photos/photo_exif.jpg").binread))

        assert result.success?
        assert_equal Ports::Assessment::QuestionImageStorePort::StoredImage.new(public_id: "img1", width: 64, height: 48), result.value
        assert_not_includes @store.writes.first[:data], "PhoneMaker"
        assert_equal "image/jpeg", @store.writes.first[:content_type]
      end

      test "une image trop lourde est refusée avec sa raison, rien n'est écrit" do
        result = upload(StringIO.new("\xFF\xD8".b + ("\0".b * (Entities::Shared::ContentImage::MAX_BYTES + 1))))

        assert_equal :invalid, result.code
        assert_equal [ "L'image dépasse 300 Ko, même allégée." ], result.errors[:file]
        assert_empty @store.writes
      end

      test "le rôle terrain, un enseignant, un élève : refus, rien n'est lu ni écrit" do
        [ actor(:team, "field"), actor(:teacher, nil), actor(:student, nil) ].each do |someone|
          assert_equal :forbidden, upload(StringIO.new(file_fixture("photos/photo.jpg").binread), actor: someone).code
        end
        assert_empty @store.writes
      end

      test "l'administration de l'équipe envoie aussi" do
        assert upload(StringIO.new(file_fixture("photos/photo.png").binread), actor: actor(:team, "admin")).success?
      end
    end
  end
end
