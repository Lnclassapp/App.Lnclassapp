require "test_helper"

# ADR-0089 §4.7 : une image envoyée puis jamais enregistrée est supprimée après 48 h ; le nombre est journalisé, zéro compris.
class Catalog::PurgeOrphanEssentialImagesJobTest < ActiveJob::TestCase
  test "supprime l'orpheline de 49 h, garde celle de 47 h, et journalise le nombre" do
    stale = create_essential_image(created_at: 49.hours.ago)
    recent = create_essential_image(created_at: 47.hours.ago)

    logs = [ capture_log { assert_equal 1, Catalog::PurgeOrphanEssentialImagesJob.perform_now },
             capture_log { assert_equal 0, Catalog::PurgeOrphanEssentialImagesJob.perform_now } ]

    assert_equal [ recent.id ], Orm::EssentialImage.ids
    assert_not Orm::EssentialImage.exists?(stale.id)
    assert_includes logs.first, "[Catalog::PurgeOrphanEssentialImagesJob] 1 orphan essential image(s) deleted"
    assert_includes logs.last, "[Catalog::PurgeOrphanEssentialImagesJob] 0 orphan essential image(s) deleted"
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
