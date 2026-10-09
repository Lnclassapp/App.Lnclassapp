require "test_helper"

# Chantier app-android, Lot B — CA-9 (ADR-0084 §4.7), CA-T7 (ADR-0086 §4.7). /.well-known/assetlinks.json is public and
# declares, from config.x.android, the two Android apps allowed to open the site's links; without a fingerprint, none.
class Identity::AssetLinksControllerTest < ActionDispatch::IntegrationTest
  FINGERPRINTS = [ "AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89",
                   "10:32:54:76:98:BA:DC:FE:10:32:54:76:98:BA:DC:FE:10:32:54:76:98:BA:DC:FE:10:32:54:76:98:BA:DC:FE" ].freeze

  def with_android(cert_fingerprints:, student: "com.lnclass.student", teacher: "com.lnclass.teacher")
    previous = Rails.configuration.x.android
    Rails.configuration.x.android = { apps: { student: { package_name: student, store_url: nil },
                                              teacher: { package_name: teacher, store_url: nil } },
                                      cert_fingerprints: }.freeze
    yield
  ensure
    Rails.configuration.x.android = previous
  end

  def statement(package_name, fingerprints)
    { "relation" => [ "delegate_permission/common.handle_all_urls" ],
      "target" => { "namespace" => "android_app", "package_name" => package_name, "sha256_cert_fingerprints" => fingerprints } }
  end

  test "CA-9, CA-T7 — without signing in, it declares both apps with the configured fingerprints" do
    with_android(cert_fingerprints: FINGERPRINTS) do
      get android_asset_links_path(format: :json)
    end

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal [ statement("com.lnclass.student", FINGERPRINTS), statement("com.lnclass.teacher", FINGERPRINTS) ],
                 response.parsed_body
  end

  test "CA-9, CA-T7 — the package names follow the environment's configuration" do
    with_android(student: "com.lnclass.student.recette", teacher: "com.lnclass.teacher.recette",
                 cert_fingerprints: FINGERPRINTS.first(1)) do
      get "/.well-known/assetlinks.json"
    end

    assert_equal [ statement("com.lnclass.student.recette", FINGERPRINTS.first(1)),
                   statement("com.lnclass.teacher.recette", FINGERPRINTS.first(1)) ], response.parsed_body
  end

  test "CA-9 — without a fingerprint, it declares nothing" do
    with_android(cert_fingerprints: []) do
      get android_asset_links_path(format: :json)
    end

    assert_response :ok
    assert_equal [], response.parsed_body
  end
end
