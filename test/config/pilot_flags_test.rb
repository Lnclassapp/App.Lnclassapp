require "test_helper"

# CA-A2 (mvp-teacher-student): the "school space" flag is off until 2 November, on by an environment variable. The home page
# (Lot D) reads it; nothing else decides whether the school space shows.
class PilotFlagsTest < ActiveSupport::TestCase
  INITIALIZER = Rails.root.join("config/initializers/pilot_flags.rb")

  def flags = Rails.configuration.x.pilot_flags

  def with_env(value)
    previous = ENV.fetch("SCHOOL_SPACE_ENABLED", nil)
    value.nil? ? ENV.delete("SCHOOL_SPACE_ENABLED") : ENV["SCHOOL_SPACE_ENABLED"] = value
    load INITIALIZER
    yield
  ensure
    previous.nil? ? ENV.delete("SCHOOL_SPACE_ENABLED") : ENV["SCHOOL_SPACE_ENABLED"] = previous
    load INITIALIZER
  end

  test "the school space flag is off by default" do
    with_env(nil) { assert_equal false, flags[:school_space_enabled] }
  end

  test "an environment variable turns it on, any other value or an empty one keeps it off" do
    %w[true 1 on TRUE].each { |value| with_env(value) { assert_equal true, flags[:school_space_enabled], value } }
    [ "false", "0", "", "off", "maybe" ].each { |value| with_env(value) { assert_equal false, flags[:school_space_enabled], value.inspect } }
  end

  test "the flags are frozen" do
    assert_predicate flags, :frozen?
    assert_raises(FrozenError) { flags[:school_space_enabled] = true }
  end
end
