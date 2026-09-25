require "test_helper"
require_relative "../support/environment_probe"

# ADR-0047 : files on the Railway bucket of the environment, served through the application.
class StorageTest < ActiveSupport::TestCase
  test "production stores files on the Railway bucket, served in proxy mode" do
    storage = EnvironmentProbe.run("production", <<~RUBY)
      service = ActiveStorage::Blob.service
      { "name" => service.name.to_s, "class" => service.class.name, "bucket" => service.bucket.name,
        "endpoint" => service.client.client.config.endpoint.to_s,
        "route" => Rails.application.config.active_storage.resolve_model_to_route.to_s }
    RUBY

    assert_equal "railway", storage["name"]
    assert_equal "ActiveStorage::Service::S3Service", storage["class"]
    assert_equal "lnclass-probe", storage["bucket"]
    assert_equal "https://t3.storageapi.dev", storage["endpoint"]
    assert_equal "rails_storage_proxy", storage["route"]
  end

  test "production refuses to boot without its bucket" do
    error = assert_raises(RuntimeError) do
      EnvironmentProbe.run("production", "ActiveStorage::Blob.service.name", env: { "BUCKET_NAME" => nil })
    end

    assert_match(/missing required option :name/, error.message)
  end

  test "tests keep files in a temporary directory, and every environment serves them in proxy mode" do
    assert_equal :test, ActiveStorage::Blob.service.name
    assert_equal :rails_storage_proxy, Rails.application.config.active_storage.resolve_model_to_route
  end
end
