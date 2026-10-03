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

  # Chantier retrait-debugbar : its middleware broadcast every request as JSON and answered 500 to all of them,
  # until a restart, once an image had gone through it. It also opened Action Cable to any origin.
  test "development boots without debugbar and keeps Action Cable's default origin check" do
    development = EnvironmentProbe.run("development", <<~RUBY)
      { "debugbar" => !defined?(Debugbar).nil?,
        "middleware" => Rails.application.middleware.map(&:name).grep(/Debugbar/),
        "cable_any_origin" => ActionCable.server.config.disable_request_forgery_protection }
    RUBY

    assert_equal({ "debugbar" => false, "middleware" => [], "cable_any_origin" => false }, development)
  end

  test "the bundle no longer locks debugbar and test keeps Action Cable's default origin check" do
    assert_empty Bundler.locked_gems.specs.map(&:name).grep("debugbar"), "Gemfile.lock"
    assert_not ActionCable.server.config.disable_request_forgery_protection
  end
end
