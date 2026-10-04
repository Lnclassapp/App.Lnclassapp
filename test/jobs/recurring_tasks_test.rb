require "test_helper"

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
end
