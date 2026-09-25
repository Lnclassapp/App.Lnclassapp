require "test_helper"
require_relative "../support/environment_probe"

# ADR-0052 and garde-fou n° 6 : development behaves like production where it matters.
class DevelopmentConfigurationTest < ActiveSupport::TestCase
  test "development runs jobs on Solid Queue and raises on a missing translation" do
    development = EnvironmentProbe.run("development", <<~RUBY)
      { "queue_adapter" => Rails.application.config.active_job.queue_adapter.to_s,
        "raise_on_missing_translations" => Rails.application.config.i18n.raise_on_missing_translations }
    RUBY

    assert_equal "solid_queue", development["queue_adapter"]
    assert development["raise_on_missing_translations"]
  end
end
