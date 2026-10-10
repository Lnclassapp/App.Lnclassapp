require "test_helper"

# ADR-0089 §4.5 : l'image d'une question se lit sous la règle de lecture de son exercice : publiée (exercice, fiche et
# cours publiés), elle se lit par toute personne connectée et se garde dans le navigateur ; brouillon ou non rattachée,
# l'équipe seule la lit, sans cache. Sinon elle est introuvable, et son fichier n'est jamais lu.
module UseCases
  module Assessment
    class ReadQuestionImageTest < ActiveSupport::TestCase
      ImageState = Ports::Assessment::QuestionImageStorePort::ImageState

      class FakeImageStore
        include Ports::Assessment::QuestionImageStorePort

        attr_reader :downloads

        def initialize(images)
          @images = images
          @downloads = []
        end

        def find(public_id:) = @images[public_id]
        def download(public_id:) = (@downloads << public_id) && "octets #{public_id}"
      end

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        def initialize(exercises) = @exercises = exercises
        def find_by_public_id(public_id:) = @exercises[public_id]
      end

      setup do
        @store = FakeImageStore.new("published" => state("ExPub"), "draft" => state("ExDraft"), "parent" => state("ExParent"),
                                    "orphan" => state(nil))
        @exercises = FakeExercises.new("ExPub" => exercise("published", true), "ExDraft" => exercise("draft", true),
                                       "ExParent" => exercise("published", false))
      end

      def state(exercise_public_id) = ImageState.new(content_type: "image/webp", exercise_public_id:)

      def exercise(status, parents_published)
        Entities::Assessment::Exercise.new(public_id: "x", status:, parents_published:, title: "E", essential_id: 1, exercise_type: "fixation")
      end

      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      def read(public_id, actor:)
        ReadQuestionImage.new(images: @store, exercises: @exercises, policy: Policies::Catalog::ReadPublishedPolicy.new)
                         .call(actor:, public_id:)
      end

      test "une image publiée se lit par l'élève, l'enseignant et l'équipe ; publique au sens du cache navigateur" do
        [ actor(:student), actor(:teacher), actor(:team, "content") ].each do |someone|
          result = read("published", actor: someone)

          assert result.success?
          assert_equal [ "image/webp", true, "ExPub" ], [ result.value.content_type, result.value.public, result.value.exercise_public_id ]
        end
        assert_empty @store.downloads
        assert_equal "octets published", read("published", actor: actor(:student)).value.data.call
      end

      test "brouillon, parent non publié ou image non rattachée : l'élève ne les trouve pas, et rien n'est lu" do
        %w[draft parent orphan inconnue].each do |public_id|
          assert_equal :not_found, read(public_id, actor: actor(:student)).code, public_id
          assert_equal :not_found, read(public_id, actor: actor(:teacher)).code, public_id
        end
        assert_empty @store.downloads
      end

      test "l'équipe lit un brouillon et une image non rattachée, sans cache" do
        %w[draft orphan].each do |public_id|
          result = read(public_id, actor: actor(:team, "content"))

          assert result.success?, public_id
          assert_not result.value.public
        end
      end

      test "un exercice disparu rend l'image introuvable" do
        @store = FakeImageStore.new("lost" => state("ExLost"))

        assert_equal :not_found, read("lost", actor: actor(:team, "admin")).code
      end
    end
  end
end
