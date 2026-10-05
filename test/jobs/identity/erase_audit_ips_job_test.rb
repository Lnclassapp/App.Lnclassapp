require "test_helper"

# RI-01 à RI-03 (ADR-0080) : la tâche du jour efface l'IP des événements de plus de 12 mois, garde les plus récents et
# journalise le nombre traité, zéro compris.
class Identity::EraseAuditIpsJobTest < ActiveJob::TestCase
  test "an event of 12 months and 1 day loses its IP and keeps the rest; one of 11 months keeps its IP" do
    old = Orm::AuditEvent.create!(action: "login.locked", actor_id: nil, subject_type: "User", subject_id: 5,
                                  metadata: { "failures" => 5 }, ip_address: "41.202.1.1", created_at: 12.months.ago - 1.day)
    recent = Orm::AuditEvent.create!(action: "login.locked", ip_address: "41.202.1.2", created_at: 11.months.ago)

    logs = capture_log { assert_equal 1, Identity::EraseAuditIpsJob.perform_now }

    assert_nil old.reload.ip_address
    assert_equal [ "login.locked", "User", 5, { "failures" => 5 } ], [ old.action, old.subject_type, old.subject_id, old.metadata ]
    assert_equal "41.202.1.2", recent.reload.ip_address
    assert_includes logs, "[Identity::EraseAuditIpsJob] 1 audit event IP(s) erased"
    assert_includes capture_log { Identity::EraseAuditIpsJob.perform_now }, "[Identity::EraseAuditIpsJob] 0 audit event IP(s) erased"
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
