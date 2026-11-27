require "test_helper"
require "fugit"

class RecurringTasksTest < ActiveSupport::TestCase
  test "every recurring task of production points to an existing job or command" do
    tasks = Rails.application.config_for(:recurring, env: "production")

    assert_not_empty tasks
    tasks.each do |key, options|
      task = SolidQueue::RecurringTask.from_configuration(key, **options)
      assert task.valid?, "#{key} : #{task.errors.full_messages.to_sentence}"
    end
  end

  # ADR-0077 §4.5 : les comptes direction archivés depuis 30 jours sont supprimés chaque nuit.
  test "the purge of archived school staff runs every day at 4am on the default queue" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:purge_archived_staff)

    assert_equal({ class: "School::PurgeArchivedStaffJob", queue: "default", schedule: "every day at 4am" }, task)
  end

  # RI-05, ADR-0080 : l'IP du journal d'audit est effacée après 12 mois, chaque nuit.
  test "the erasure of old audit IPs runs every day at 4:30am on the default queue" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:erase_audit_ips)

    assert_equal({ class: "Identity::EraseAuditIpsJob", queue: "default", schedule: "every day at 4:30am" }, task)
  end

  # ADR-0147 §4.3 (porteur, 2026-11-27) : un passage tombe à chaque ouverture des fenêtres d'Abidjan (12 h 20, 18 h, et 9 h
  # le dimanche), et le dernier avant chaque fermeture (20 h 20 en semaine, 20 h le dimanche) est dans la fenêtre.
  test "the push passes fall on each opening of the sending windows, and inside them until they close" do
    tasks = Rails.application.config_for(:recurring, env: "production")
    schedules = %i[deliver_push_notifications deliver_push_notifications_at_noon_opening].map do |key|
      assert_equal "Communication::DeliverPushNotificationsJob", tasks.fetch(key)[:class]
      Fugit.parse(tasks.fetch(key)[:schedule])
    end
    first_pass = ->(from) { schedules.map { it.next_time(from - 1).to_t.utc }.min }
    monday = Time.utc(2026, 11, 23)
    sunday = Time.utc(2026, 11, 29)

    assert_equal monday + 12.hours + 20.minutes, first_pass.(monday + 12.hours + 20.minutes)
    assert_equal monday + 18.hours, first_pass.(monday + 18.hours)
    assert_equal sunday + 9.hours, first_pass.(sunday + 9.hours)
    assert_equal sunday + 9.hours, first_pass.(sunday + 8.hours + 50.minutes), "pas de passage de 12 h 20 avant le dimanche"
    assert Entities::Communication::SendingWindow.open?(monday + 20.hours + 15.minutes)
    assert_equal sunday + 12.hours + 30.minutes, first_pass.(sunday + 12.hours + 16.minutes), "le dimanche, pas de passage de 12 h 20"
  end
end
