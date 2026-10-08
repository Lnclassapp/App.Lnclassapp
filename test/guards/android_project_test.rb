# Pure Ruby, no compilation: the Android shell (android/, ADR-0084 §4.8) keeps the contract the site relies on
# (CA-10). The APK itself is built by bin/android-build, outside the Rails CI.
require "minitest/autorun"
require "json"
require "open3"

class AndroidProjectTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  MODULE = "android/student"
  SOURCES = "#{MODULE}/src/main/java/com/lnclass/student".freeze

  def read(path) = File.read(File.join(ROOT, path))

  def gradle = read("#{MODULE}/build.gradle.kts")

  def flavor(name) = gradle[/create\("#{name}"\)\s*\{(.*?)^\s{8}\}/m, 1].to_s

  def test_android_9_is_the_floor
    assert_match(/^\s*minSdk = 28\b/, gradle, "ADR-0070 amendé : Android 9 (API 28), plancher de Hotwire Native")
  end

  # Two test levels before production (Develop, then Staging), each installable next to the other.
  def test_the_three_variants_install_side_by_side_and_load_their_site
    assert_match(/applicationId = "com\.lnclass\.student"/, gradle)
    assert_match(/applicationIdSuffix = "\.develop"/, flavor("develop"))
    assert_includes flavor("develop"), %("\\"https://app-develop.lnclass.com\\"")
    assert_match(/applicationIdSuffix = "\.recette"/, flavor("recette"))
    assert_includes flavor("recette"), %("\\"https://app-staging.lnclass.com\\"")
    assert_includes flavor("production"), %("\\"https://lnclass.com\\"")
    refute_match(/applicationIdSuffix/, flavor("production"))
  end

  # ADR-0084 §4.1 : the token the shell adds is the one ApplicationController#lnclass_app looks for.
  def test_the_user_agent_carries_the_token_the_site_recognizes
    token = read("app/controllers/application_controller.rb")[/"(\w+)" => :android_student/, 1]

    assert_equal "LnclassStudentAndroid", token
    assert_includes read("#{SOURCES}/StudentApplication.kt"),
                    %(applicationUserAgentPrefix = "#{token}/${BuildConfig.VERSION_NAME};")
  end

  def test_three_tabs_start_on_home_courses_and_classroom
    starts = read("#{SOURCES}/MainActivity.kt").scan(/tab\("\w+", R\.string\.\w+, R\.drawable\.\w+, "([^"]+)"/).flatten

    assert_equal [ "/?source=android", "/courses", "/students/classroom" ], starts
  end

  def test_class_links_open_in_the_app
    manifest = read("#{MODULE}/src/main/AndroidManifest.xml")

    assert_match(/<intent-filter android:autoVerify="true">/, manifest)
    assert_includes manifest, %(<data android:pathPrefix="/c/" />)
    assert_includes manifest, %(<data android:path="/join" />)
  end

  # ADR-0084 §4.8 : no signing key in the repository.
  def test_no_signing_key_is_versioned
    files, status = Open3.capture2("git", "-C", ROOT, "ls-files", "--", "android", "*.jks", "*.keystore")

    assert status.success?, "git ls-files a échoué"
    assert_empty files.lines.map(&:chomp).grep(/\.(jks|keystore)\z/), "clé de signature versionnée"
    assert_includes read("android/.gitignore").lines.map(&:chomp), "*.jks"
    assert_includes read("android/.gitignore").lines.map(&:chomp), "*.keystore"
  end

  # ADR-0084 §4.3 : the embedded copy, for an offline start, is the one the site serves; before that file exists,
  # the reference is the ADR itself.
  def test_the_embedded_path_configuration_is_the_one_the_site_serves
    embedded = JSON.parse(read("#{MODULE}/src/main/assets/json/path-configuration.json"))
    served = "public/android/v1/path-configuration.json"
    reference = File.exist?(File.join(ROOT, served)) ? read(served) : adr_path_configuration

    assert_equal JSON.parse(reference), embedded
    assert_includes read("#{SOURCES}/StudentApplication.kt"), %(remoteFileUrl = "${BuildConfig.BASE_URL}/#{served.delete_prefix('public/')}")
  end

  private

  def adr_path_configuration
    block = read("docs/decisions/adr/0084-coque-android-eleves-hotwire-native.md")[/```json\n(.*?)```/m, 1]
    block.lines.grep_v(%r{\A\s*//}).join
  end
end
