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
end
