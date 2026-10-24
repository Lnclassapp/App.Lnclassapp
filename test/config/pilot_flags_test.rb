require "test_helper"

# CA-A2 (mvp-teacher-student): the "school space" flag is off until 2 November, on by an environment variable. The home page
# (Lot D) reads it; nothing else decides whether the school space shows. The teacher's announcements (decision of
# 24 October) follow the same rule: off for the pilot, on by TEACHER_ANNOUNCEMENTS_ENABLED.
class PilotFlagsTest < ActiveSupport::TestCase
  INITIALIZER = Rails.root.join("config/initializers/pilot_flags.rb")
  VARIABLES = { school_space_enabled: "SCHOOL_SPACE_ENABLED", teacher_announcements_enabled: "TEACHER_ANNOUNCEMENTS_ENABLED" }.freeze

  def flags = Rails.configuration.x.pilot_flags

  def with_env(name, value)
    previous = ENV.fetch(name, nil)
    value.nil? ? ENV.delete(name) : ENV[name] = value
    load INITIALIZER
    yield
  ensure
    previous.nil? ? ENV.delete(name) : ENV[name] = previous
    load INITIALIZER
  end

  test "every flag is off by default" do
    VARIABLES.each { |flag, name| with_env(name, nil) { assert_equal false, flags[flag], flag } }
  end

  test "an environment variable turns its flag on, any other value or an empty one keeps it off" do
    VARIABLES.each do |flag, name|
      %w[true 1 on TRUE].each { |value| with_env(name, value) { assert_equal true, flags[flag], "#{name}=#{value}" } }
      [ "false", "0", "", "off", "maybe" ].each { |value| with_env(name, value) { assert_equal false, flags[flag], "#{name}=#{value.inspect}" } }
      with_env(name, "true") { assert_equal false, flags[(VARIABLES.keys - [ flag ]).first], "#{name} turns on its flag only" }
    end
  end

  test "the flags are frozen" do
    assert_predicate flags, :frozen?
    assert_raises(FrozenError) { flags[:school_space_enabled] = true }
  end
end
