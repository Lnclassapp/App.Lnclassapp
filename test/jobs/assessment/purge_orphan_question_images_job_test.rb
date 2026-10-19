require "test_helper"

# ADR-0105 §4.7 : une image envoyée puis jamais enregistrée est supprimée après 48 h ; le nombre est journalisé, zéro compris.
class Assessment::PurgeOrphanQuestionImagesJobTest < ActiveJob::TestCase
  test "supprime l'orpheline de 49 h, garde celle de 47 h, et journalise le nombre" do
    stale = create_question_image(created_at: 49.hours.ago)
    recent = create_question_image(created_at: 47.hours.ago)
    blob = stale.file.blob

    logs = [ capture_log { perform_enqueued_jobs { assert_equal 1, Assessment::PurgeOrphanQuestionImagesJob.perform_now } },
             capture_log { assert_equal 0, Assessment::PurgeOrphanQuestionImagesJob.perform_now } ]

    assert_equal [ recent.id ], Orm::QuestionImage.ids
    assert_not Orm::QuestionImage.exists?(stale.id)
    assert_not ActiveStorage::Blob.exists?(blob.id), "le fichier part avec la ligne"
    assert ActiveStorage::Blob.exists?(recent.file.blob.id)
    assert_includes logs.first, "[Assessment::PurgeOrphanQuestionImagesJob] 1 orphan question image(s) deleted"
    assert_includes logs.last, "[Assessment::PurgeOrphanQuestionImagesJob] 0 orphan question image(s) deleted"
  end

  private

  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end
