require "test_helper"
require "puma"
require "puma/configuration"
require "erb"
require "yaml"

# ADR-0108 §4 (amends ADR-0052 §4): in a PR environment, the Solid Queue worker is not loaded by Puma and Action Cable
# runs in the web process (async). Everywhere else, the worker runs inside Puma and Action Cable uses Solid Cable.
class PrEnvironmentRuntimeTest < ActiveSupport::TestCase
  PR_ENV = { "PR_BASE_ENVIRONMENT" => "Develop", "RAILWAY_ENVIRONMENT_NAME" => "lnclass-pr-276" }.freeze
  OTHER_ENV = { "PR_BASE_ENVIRONMENT" => nil, "RAILWAY_ENVIRONMENT_NAME" => "production" }.freeze

  # Runs the block with ENV set to `values` (nil removes a variable), then restores it.
  def with_env(values)
    saved = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end

  # Puma's own configuration, except that asking for a plugin only records its name: nothing is required or started.
  class RecordingConfiguration < Puma::Configuration
    def requested_plugins = @requested_plugins ||= []

    def load_plugin(name)
      requested_plugins << name.to_s
      Object.new
    end
  end

  # The plugins Puma would load from config/puma.rb, read without starting a server.
  def puma_plugins(env)
    with_env(env) do
      configuration = RecordingConfiguration.new({ config_files: [ Rails.root.join("config/puma.rb").to_s ] })
      configuration.load
      configuration.requested_plugins
    end
  end

  # The production Action Cable adapter declared by config/cable.yml.
  def cable_adapter(env)
    with_env(env) do
      YAML.safe_load(ERB.new(Rails.root.join("config/cable.yml").read).result).dig("production", "adapter")
    end
  end

  test "Puma does not load the Solid Queue worker in a PR environment" do
    assert_not_includes puma_plugins(PR_ENV), "solid_queue"
  end

  test "Puma still loads the Solid Queue worker outside a PR environment" do
    assert_includes puma_plugins(OTHER_ENV), "solid_queue"
    assert_includes puma_plugins(OTHER_ENV.merge("RAILWAY_ENVIRONMENT_NAME" => nil)), "solid_queue"
    assert_includes puma_plugins(PR_ENV.merge("RAILWAY_ENVIRONMENT_NAME" => "Develop")), "solid_queue"
  end

  test "Puma keeps its other plugins in a PR environment" do
    assert_includes puma_plugins(PR_ENV), "tmp_restart"
  end

  test "Action Cable runs in the web process in a PR environment" do
    assert_equal "async", cable_adapter(PR_ENV)
  end

  test "Action Cable uses Solid Cable outside a PR environment" do
    assert_equal "solid_cable", cable_adapter(OTHER_ENV)
    assert_equal "solid_cable", cable_adapter(PR_ENV.merge("RAILWAY_ENVIRONMENT_NAME" => "Develop"))
  end

  test "production keeps its Solid Cable settings" do
    production = with_env(OTHER_ENV) { YAML.safe_load(ERB.new(Rails.root.join("config/cable.yml").read).result).fetch("production") }

    assert_equal "0.1.seconds", production["polling_interval"]
    assert_equal "1.day", production["message_retention"]
  end
end
