# Pure Ruby, no compilation: the Android shells (android/, ADR-0084 §4.8, ADR-0086 §4.8) keep the contract the site
# relies on (CA-10, CA-T8). The APKs themselves are built by bin/android-build, outside the Rails CI.
require "minitest/autorun"
require "json"
require "open3"

class AndroidProjectTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SERVED = "public/android/v1/path-configuration.json"

  # One entry per app module: what each shell must carry (ADR-0084 §4.4 and §4.7, ADR-0086 §4.3 and §4.7).
  APPS = {
    "student" => {
      application_id: "com.lnclass.student", app_name: "Lnclass", shell: :android_student,
      application_class: "StudentApplication", menu: "/students/menu",
      tabs: [ "/?source=android", "/courses", "/students/classroom" ],
      links: [ %(<data android:pathPrefix="/c/" />), %(<data android:path="/join" />),
               %(<data android:path="/student-signup" />) ]
    },
    "teacher" => {
      application_id: "com.lnclass.teacher", app_name: "Lnclass Teacher", shell: :android_teacher,
      application_class: "TeacherApplication", menu: "/teachers/menu",
      tabs: [ "/?source=android", "/teachers/classrooms", "/courses", "/announcements" ],
      links: [ %(<data android:path="/teacher-signup" />), %(<data android:pathPrefix="/i/" />) ]
    }
  }.freeze

  def read(path) = File.read(File.join(ROOT, path))

  def gradle(app) = read("android/#{app}/build.gradle.kts")

  def sources(app) = "android/#{app}/src/main/java/com/lnclass/#{app}"

  def flavor(app, name) = gradle(app)[/create\("#{name}"\)\s*\{(.*?)^\s{8}\}/m, 1].to_s

  def test_both_apps_sit_on_the_shared_shell
    assert_match(/include\(":shell", ":student", ":teacher"\)/, read("android/settings.gradle.kts"))
    assert_match(/id\("com\.android\.library"\)/, read("android/shell/build.gradle.kts"))
    assert_match(/namespace = "com\.lnclass\.shell"/, read("android/shell/build.gradle.kts"))
    APPS.each_key { |app| assert_includes gradle(app), %(implementation(project(":shell"))), app }
  end

  def test_android_9_is_the_floor
    [ "shell", *APPS.keys ].each do |mod|
      assert_match(/^\s*minSdk = 28\b/, read("android/#{mod}/build.gradle.kts"),
                   "ADR-0070 amendé : Android 9 (API 28), plancher de Hotwire Native (#{mod})")
    end
  end

  # Two test levels before production (Develop, then Staging), each installable next to the other.
  def test_the_three_variants_install_side_by_side_and_load_their_site
    APPS.each do |app, spec|
      assert_match(/applicationId = "#{Regexp.escape(spec[:application_id])}"/, gradle(app))
      assert_match(/applicationIdSuffix = "\.develop"/, flavor(app, "develop"))
      assert_includes flavor(app, "develop"), %("\\"https://app-develop.lnclass.com\\"")
      assert_includes flavor(app, "develop"), %(resValue("string", "app_name", "#{spec[:app_name]} develop"))
      assert_match(/applicationIdSuffix = "\.recette"/, flavor(app, "recette"))
      assert_includes flavor(app, "recette"), %("\\"https://app-staging.lnclass.com\\"")
      assert_includes flavor(app, "recette"), %(resValue("string", "app_name", "#{spec[:app_name]} recette"))
      assert_includes flavor(app, "production"), %("\\"https://lnclass.com\\"")
      assert_includes flavor(app, "production"), %(resValue("string", "app_name", "#{spec[:app_name]}"))
      refute_match(/applicationIdSuffix/, flavor(app, "production"))
    end
  end

  # ADR-0084 §4.1, ADR-0086 §4.1 : the token each shell adds is the one ApplicationController#lnclass_app looks for.
  def test_the_user_agent_carries_the_token_the_site_recognizes
    controller = read("app/controllers/application_controller.rb")

    APPS.each do |app, spec|
      token = controller[/"(\w+)" => :#{spec[:shell]}\b/, 1]

      assert token, "jeton de #{spec[:shell]} absent de LNCLASS_APPS"
      assert_includes read("#{sources(app)}/#{spec[:application_class]}.kt"),
                      %(userAgentPrefix = "#{token}/${BuildConfig.VERSION_NAME};")
    end
    assert_includes read("android/shell/src/main/java/com/lnclass/shell/Shell.kt"),
                    "Hotwire.config.applicationUserAgentPrefix = userAgentPrefix"
  end

  def test_each_app_opens_its_own_account_panel
    APPS.each do |app, spec|
      assert_includes read("#{sources(app)}/#{spec[:application_class]}.kt"), %(accountMenuPath = "#{spec[:menu]}")
    end
  end

  def test_each_app_has_its_tabs
    APPS.each do |app, spec|
      starts = read("#{sources(app)}/MainActivity.kt").scan(/tab\("\w+", R\.string\.\w+, R\.drawable\.\w+, "([^"]+)"/).flatten

      assert_equal spec[:tabs], starts, app
    end
  end

  def test_each_app_opens_its_own_links
    APPS.each do |app, spec|
      manifest = read("android/#{app}/src/main/AndroidManifest.xml")

      assert_match(/<intent-filter android:autoVerify="true">/, manifest)
      spec[:links].each { |link| assert_includes manifest, link, app }
      (APPS.values - [ spec ]).flat_map { |other| other[:links] }.each { |link| refute_includes manifest, link, app }
    end
  end

  # ADR-0084 §4.8 : no signing key in the repository.
  def test_no_signing_key_is_versioned
    files, status = Open3.capture2("git", "-C", ROOT, "ls-files", "--", "android", "*.jks", "*.keystore")

    assert status.success?, "git ls-files a échoué"
    assert_empty files.lines.map(&:chomp).grep(/\.(jks|keystore)\z/), "clé de signature versionnée"
    assert_includes read("android/.gitignore").lines.map(&:chomp), "*.jks"
    assert_includes read("android/.gitignore").lines.map(&:chomp), "*.keystore"
  end

  # ADR-0084 §4.3, ADR-0086 §4.3 : one file for both apps; each embedded copy, for an offline start, is the one the
  # site serves.
  def test_the_embedded_path_configurations_are_the_one_the_site_serves
    served = JSON.parse(read(SERVED))

    APPS.each_key do |app|
      assert_equal served, JSON.parse(read("android/#{app}/src/main/assets/json/path-configuration.json")), app
    end
    assert_includes read("android/shell/src/main/java/com/lnclass/shell/Shell.kt"),
                    %(remoteFileUrl = "$baseUrl/#{SERVED.delete_prefix('public/')}")
  end
end
