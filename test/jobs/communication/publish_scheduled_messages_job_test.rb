require "test_helper"

# AN-07, ADR-0045 §4 and ADR-0078 §4.5: every 5 minutes (config/recurring.yml, production), the job publishes the
# scheduled announcements whose time has come, on the real repositories; the others stay scheduled and unreadable.
class Communication::PublishScheduledMessagesJobTest < ActiveJob::TestCase
  setup do
    @school = create_school
    @kamate = create_school_admin(school: @school, last_name: "Kamaté")
    @morning = create_message(author: @kamate, school: @school, status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 10))
    @evening = create_message(author: @kamate, school: @school, status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 18))
  end

  test "AN-07 — run at 10:05, the job publishes the announcement of 10:00 and journals it; the one of 18:00 waits" do
    travel_to Time.zone.local(2026, 10, 1, 10, 5) do
      Communication::PublishScheduledMessagesJob.perform_now
    end

    assert_equal "published", @morning.reload.status
    assert_equal "scheduled", @evening.reload.status
    assert_equal [ [ @kamate.id, @morning.id ] ], Orm::AuditEvent.where(action: "message.published").pluck(:actor_id, :subject_id)
  end

  test "the job logs the number of announcements published, zero included (B-030)" do
    log = capture_log do
      travel_to(Time.zone.local(2026, 10, 1, 10, 5)) { Communication::PublishScheduledMessagesJob.perform_now }
      travel_to(Time.zone.local(2026, 10, 1, 10, 10)) { Communication::PublishScheduledMessagesJob.perform_now }
    end

    assert_includes log, "[Communication::PublishScheduledMessagesJob] 1 scheduled announcement(s) published"
    assert_includes log, "[Communication::PublishScheduledMessagesJob] 0 scheduled announcement(s) published"
  end

  test "a teacher's scheduled announcement is published while teachers may write, and archived once the flag is off (B-043)" do
    classroom = create_classroom(school: @school)
    teacher = create_teacher(school: @school, classrooms: [ classroom ])
    first, second = [ 10, 11 ].map do |hour|
      create_message(author: teacher, audience: "classrooms", classrooms: [ classroom ], status: "scheduled",
                     published_at: Time.zone.local(2026, 10, 1, hour))
    end

    pilot_flags!(teacher_announcements_enabled: true)
    travel_to(Time.zone.local(2026, 10, 1, 10, 5)) { Communication::PublishScheduledMessagesJob.perform_now }
    pilot_flags!(teacher_announcements_enabled: false)
    travel_to(Time.zone.local(2026, 10, 1, 11, 5)) { Communication::PublishScheduledMessagesJob.perform_now }

    assert_equal %w[published archived], [ first.reload.status, second.reload.status ]
  end

  test "the job runs every 5 minutes in production, on the default queue" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:publish_scheduled_messages)

    assert_equal({ class: "Communication::PublishScheduledMessagesJob", queue: "default", schedule: "every 5 minutes" }, task)
  end
end
