require "test_helper"

# Chantier app-android, Lot B — CA-9 (ADR-0084 §4.7). /.well-known/assetlinks.json is public and declares, from
# config.x.android, the Android app allowed to open the site's links; without a configured fingerprint it declares none.
class Identity::AssetLinksControllerTest < ActionDispatch::IntegrationTest
  FINGERPRINTS = [ "AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89",
                   "10:32:54:76:98:BA:DC:FE:10:32:54:76:98:BA:DC:FE:10:32:54:76:98:BA:DC:FE:10:32:54:76:98:BA:DC:FE" ].freeze

  def with_android(package_name:, cert_fingerprints:)
    previous = Rails.configuration.x.android
    Rails.configuration.x.android = { package_name:, cert_fingerprints: }.freeze
    yield
  ensure
    Rails.configuration.x.android = previous
  end

  test "CA-9 — without signing in, it declares com.lnclass.student and the configured fingerprints" do
    with_android(package_name: "com.lnclass.student", cert_fingerprints: FINGERPRINTS) do
      get android_asset_links_path(format: :json)
    end

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal [ { "relation" => [ "delegate_permission/common.handle_all_urls" ],
                     "target" => { "namespace" => "android_app", "package_name" => "com.lnclass.student",
                                   "sha256_cert_fingerprints" => FINGERPRINTS } } ], response.parsed_body
  end

  test "CA-9 — the package name follows the environment's configuration" do
    with_android(package_name: "com.lnclass.student.recette", cert_fingerprints: FINGERPRINTS.first(1)) do
      get "/.well-known/assetlinks.json"
    end

    assert_equal "com.lnclass.student.recette", response.parsed_body.sole.dig("target", "package_name")
    assert_equal FINGERPRINTS.first(1), response.parsed_body.sole.dig("target", "sha256_cert_fingerprints")
  end

  test "CA-9 — without a fingerprint, it declares nothing" do
    with_android(package_name: "com.lnclass.student", cert_fingerprints: []) do
      get android_asset_links_path(format: :json)
    end

    assert_response :ok
    assert_equal [], response.parsed_body
  end
end
