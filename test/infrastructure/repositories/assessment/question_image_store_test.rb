require "test_helper"

# ADR-0089 §4.7 : l'image d'une question est une ligne de question_images (une au plus par question) et son fichier ;
# elle se lit avec l'exercice de sa question ; une orpheline de plus de 48 h est purgée.
module Repositories
  module Assessment
    class QuestionImageStoreTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      Port = Ports::Assessment::QuestionImageStorePort

      setup do
        @store = QuestionImageStore.new
        @webp = file_fixture("photos/photo_lossy.webp").binread
      end

      test "store garde les octets, sans analyse, rattachés à aucune question" do
        stored = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)
        image = Orm::QuestionImage.find_by!(public_id: stored.public_id)

        assert_equal Port::StoredImage.new(public_id: image.public_id, width: 64, height: 48), stored
        assert_equal [ nil, "image/webp", 64, 48 ], [ image.question_id, image.content_type, image.width, image.height ]
        assert_equal @webp, image.file.download
      end

      test "find rend le format et l'exercice ; nil pour une image inconnue" do
        exercise = create_exercise
        attached = create_question_image(question: exercise.questions.first, fixture: "photos/photo.png")
        orphan = create_question_image

        assert_equal Port::ImageState.new(content_type: "image/png", exercise_public_id: exercise.public_id), @store.find(public_id: attached.public_id)
        assert_equal Port::ImageState.new(content_type: "image/jpeg", exercise_public_id: nil), @store.find(public_id: orphan.public_id)
        assert_nil @store.find(public_id: "inconnu0000000")
      end

      test "download rend les octets ; nil pour une image inconnue" do
        stored = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)

        assert_equal @webp, @store.download(public_id: stored.public_id)
        assert_nil @store.download(public_id: "inconnu0000000")
      end

      test "purge_orphans supprime les orphelines anciennes seulement" do
        old = create_question_image(created_at: 49.hours.ago)
        recent = create_question_image(created_at: 47.hours.ago)
        attached = create_question_image(question: create_exercise.questions.first, created_at: 30.days.ago)

        assert_equal 1, perform_enqueued_jobs { @store.purge_orphans(before: 48.hours.ago) }
        assert_equal [ recent, attached ].map(&:id).sort, Orm::QuestionImage.pluck(:id).sort
        assert_not Orm::QuestionImage.exists?(old.id)
      end

      test "une question a au plus une image" do
        question = create_exercise.questions.first
        create_question_image(question:)

        assert_raises(ActiveRecord::RecordNotUnique) { create_question_image(question:) }
      end
    end
  end
end
