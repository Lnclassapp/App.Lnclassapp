require "test_helper"

# AN-07, ADR-0045 §4 and ADR-0078 §4.5: every 5 minutes (config/recurring.yml, production), the job publishes the
# scheduled announcements whose time has come, on the real repositories; the others stay scheduled and unreadable.
class Communication::PublishScheduledMessagesJobTest < ActiveJob::TestCase
  setup do
    @kamate = create_school_admin(last_name: "Kamaté")
    @morning = create_message(author: @kamate, status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 10))
    @evening = create_message(author: @kamate, status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 18))
  end

  test "AN-07 — run at 10:05, the job publishes the announcement of 10:00 and journals it; the one of 18:00 waits" do
    travel_to Time.zone.local(2026, 10, 1, 10, 5) do
      Communication::PublishScheduledMessagesJob.perform_now
    end

    assert_equal "published", @morning.reload.status
    assert_equal "scheduled", @evening.reload.status
    assert_equal [ [ @kamate.id, @morning.id ] ], Orm::AuditEvent.where(action: "message.published").pluck(:actor_id, :subject_id)
  end

  test "the job runs every 5 minutes in production, on the default queue" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:publish_scheduled_messages)

    assert_equal({ class: "Communication::PublishScheduledMessagesJob", queue: "default", schedule: "every 5 minutes" }, task)
  end
end
