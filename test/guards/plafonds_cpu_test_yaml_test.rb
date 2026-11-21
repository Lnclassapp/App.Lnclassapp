# Pure Ruby, no Rails boot: the CPU ceilings of the Develop and Staging stack (deploy/hostinger/test.yaml).
# They stay capped so the production keeps priority, but high enough for pages to answer fast.
require "minitest/autorun"
require "yaml"

class PlafondsCpuTestYamlTest < Minitest::Test
  FILE = File.expand_path("../../deploy/hostinger/test.yaml", __dir__)
  HOSTINGER_LIMIT = 8192

  def services = YAML.safe_load_file(FILE, aliases: true).fetch("services")

  def test_database_cpu_ceiling_is_present_and_at_most_half_a_core
    cpus = services.fetch("db")["cpus"]

    refute_nil cpus
    assert_operator cpus.to_f, :>, 0
    assert_operator cpus.to_f, :<=, 0.5
  end

  def test_application_cpu_ceiling_is_present_and_at_most_one_core
    cpus = services.fetch("app")["cpus"]

    refute_nil cpus
    assert_operator cpus.to_f, :>, 0
    assert_operator cpus.to_f, :<=, 1.0
  end

  def test_cpu_shares_keep_the_priority_of_the_production
    %w[db app].each { |name| assert_equal 256, services.fetch(name)["cpu_shares"], name }
  end

  def test_file_stays_under_the_hostinger_limit
    assert_operator File.size(FILE), :<, HOSTINGER_LIMIT
  end
end
