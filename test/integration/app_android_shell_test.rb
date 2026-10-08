require "test_helper"

# Chantier app-android, Lot B — CA-1 (ADR-0084 §4.2, UDR-0080 §3.3). Served to the Android shell, a page of the shell layout
# loses the site's navigation (header, sidebar, bottom bar) and the install pop-up; a student's page declares the bridge
# element that feeds the native top bar. The same page in a browser is unchanged.
class AppAndroidShellTest < ActionDispatch::IntegrationTest
  APP = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
        "Hotwire Native Android; LnclassStudentAndroid/1.0".freeze
  BRIDGE = "[data-controller='bridge--account']".freeze

  def in_app = { "User-Agent" => APP }

  test "CA-1 — in the shell, the student's home has neither header nor bottom bar, but the bridge element" do
    sign_in_as create_student(classroom: create_classroom)

    get student_home_path, headers: in_app

    assert_response :ok
    assert_select "header", 0
    assert_select "aside", 0
    assert_select "nav[aria-label='#{I18n.t('shared.navigation.bottom_bar.label')}']", 0
    assert_select "a[href='#main']", 0
    assert_select "#install_banner", 0
    assert_select "[data-controller~=install]", 0
    assert_select "main#main:not(.pb-28):not(.lg\\:pl-rail)"
    assert_select "#{BRIDGE}[hidden]", count: 1 do |element|
      assert_equal({ "data-bridge--account-initials-value" => "AK", "data-bridge--account-menu-url-value" => "/students/menu",
                     "data-bridge--account-help-url-value" => "/aide" },
                   element.first.to_h.select { |name, _| name.end_with?("-value") })
    end
  end

  test "CA-1 — the same page in a browser keeps header, sidebar, bottom bar and install pop-up, without bridge element" do
    sign_in_as create_student(classroom: create_classroom)

    get student_home_path

    assert_response :ok
    assert_select "header"
    assert_select "aside"
    assert_select "nav[aria-label='#{I18n.t('shared.navigation.bottom_bar.label')}']"
    assert_select "#install_banner"
    assert_select "main#main.pb-28.lg\\:pl-rail"
    assert_select BRIDGE, 0
  end

  test "CA-1 — « Hotwire Native » without the Lnclass token is a browser" do
    sign_in_as create_student(classroom: create_classroom)

    get student_home_path, headers: { "User-Agent" => APP.sub(/; LnclassStudentAndroid.*/, "") }

    assert_select "header"
    assert_select BRIDGE, 0
  end

  test "CA-1 — the bridge element carries the student's photo when there is one" do
    student = attach_photo(create_student(classroom: create_classroom))
    version = Queries::Identity::PhotoVersions.for(user_ids: [ student.id ])[student.id]
    sign_in_as student

    get courses_path, headers: in_app

    assert_response :ok
    assert_select "#{BRIDGE}[data-bridge--account-photo-url-value='#{account_photo_path(student.public_id, v: version)}']"
  end

  test "CA-1 — without a photo, the attribute is absent" do
    sign_in_as create_student(classroom: create_classroom)

    get courses_path, headers: in_app

    assert_select BRIDGE
    assert_select "#{BRIDGE}[data-bridge--account-photo-url-value]", 0
  end

  test "CA-1 — a teacher seen through the shell has no site navigation and no bridge element" do
    sign_in_as create_teacher

    get teacher_home_path, headers: in_app

    assert_response :ok
    assert_select "header", 0
    assert_select "#install_banner", 0
    assert_select BRIDGE, 0
  end
end
