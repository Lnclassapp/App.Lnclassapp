require "test_helper"
require Rails.root.join("config/storage_service").to_s

# ADR-0140, amendement du 2026-11-17 : Staging et Develop gardent leurs fichiers sur un volume, la production jamais.
class StorageServiceTest < ActiveSupport::TestCase
  def service(value, environment = "Staging")
    StorageService.for({ "ACTIVE_STORAGE_SERVICE" => value, "RAILWAY_ENVIRONMENT_NAME" => environment }.compact)
  end

  test "without the variable, the bucket of the environment" do
    assert_equal :railway, service(nil)
    assert_equal :railway, service("  ")
    assert_equal :railway, service(nil, "production")
  end

  test "a test environment may keep its files on its volume" do
    assert_equal :local, service("local", "Staging")
    assert_equal :local, service(" local ", "Develop")
  end

  test "the production refuses local, whatever the case: its container keeps no file" do
    [ "production", "Production", " production " ].each do |name|
      error = assert_raises(ArgumentError) { service("local", name) }
      assert_match "refused in production", error.message
    end
  end

  test "any other service is refused, the test service included" do
    [ "test", "amazon", "Local" ].each do |value|
      assert_raises(ArgumentError, value) { service(value) }
    end
  end
end
