require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  class EchoJob < ApplicationJob
    def perform(message) = message
  end

  test "a job built on ApplicationJob is enqueued then performed" do
    assert_enqueued_with(job: EchoJob, args: [ "ping" ]) { EchoJob.perform_later("ping") }
    assert_equal "ping", EchoJob.perform_now("ping")
  end
end
