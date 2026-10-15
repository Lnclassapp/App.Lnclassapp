require "test_helper"

# Chantier app-android, Lot B — CA-1 (ADR-0084 §4.2, UDR-0080 §3.3); Lnclass Teacher, Lot TB — CA-T1 (ADR-0086 §4.2).
# Served to an Android shell, a page of the shell layout loses the site's navigation (header, sidebar, bottom bar) and the
# install pop-up; a student's or a teacher's page declares the bridge element that feeds the native top bar, with the
# address of their account panel. The same page in a browser is unchanged.
class AppAndroidShellTest < ActionDispatch::IntegrationTest
  APP = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
        "Hotwire Native Android; LnclassStudentAndroid/1.0".freeze
  TEACHER_APP = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
                "Hotwire Native Android; LnclassTeacherAndroid/1.0".freeze
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

  # UDR-0084 §3.3 (accueil-eleve): in a browser, the student has no bottom bar any more; the margin it needed goes.
  test "CA-1 — the same page in a browser keeps header, sidebar and install pop-up, without bridge element" do
    sign_in_as create_student(classroom: create_classroom)

    get student_home_path

    assert_response :ok
    assert_select "header"
    assert_select "aside"
    assert_select "nav.fixed.bottom-0", 0
    assert_select "#install_banner"
    assert_select "main#main.pb-12.lg\\:pl-rail:not(.pb-28)"
    assert_select BRIDGE, 0
  end

  # CA-19 (accueil-eleve) — UDR-0084 §3.2: the app is unchanged. The account panel the native top bar opens is still
  # /students/menu, the panel as a page, without the site's navigation.
  test "CA-19 — in the shell, /students/menu still serves the account panel, without header nor bottom bar" do
    sign_in_as create_student(classroom: create_classroom, first_name: "Awa", last_name: "Koné")

    get student_menu_path, headers: in_app

    assert_response :ok
    assert_select "header", 0
    assert_select "nav[aria-label='#{I18n.t('shared.navigation.bottom_bar.label')}']", 0
    assert_select "main #student_menu" do
      assert_select "p", "Awa Koné"
      assert_select "nav a[href='#{profile_path}']", I18n.t("shared.navigation.profile")
      assert_select "form[action='#{session_path}'] button", I18n.t("shared.navigation.sign_out")
    end
    assert_select "#avatar-menu", 0
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

  test "CA-T1 — in the teachers' shell, the teacher's home has no site navigation, but the bridge element to /teachers/menu" do
    sign_in_as create_teacher

    get teacher_home_path, headers: { "User-Agent" => TEACHER_APP }

    assert_response :ok
    assert_select "header", 0
    assert_select "aside", 0
    assert_select "nav[aria-label='#{I18n.t('shared.navigation.bottom_bar.label')}']", 0
    assert_select "a[href='#main']", 0
    assert_select "#install_banner", 0
    assert_select "main#main:not(.pb-28):not(.lg\\:pl-rail)"
    assert_select "#{BRIDGE}[hidden]", count: 1 do |element|
      assert_equal({ "data-bridge--account-initials-value" => "AK", "data-bridge--account-menu-url-value" => "/teachers/menu",
                     "data-bridge--account-help-url-value" => "/aide" },
                   element.first.to_h.select { |name, _| name.end_with?("-value") })
    end
  end

  test "CA-T1 — the teacher's same page in a browser keeps header, sidebar and bottom bar, without bridge element" do
    sign_in_as create_teacher

    get teacher_home_path

    assert_response :ok
    assert_select "header"
    assert_select "aside"
    assert_select "nav[aria-label='#{I18n.t('shared.navigation.bottom_bar.label')}']"
    assert_select "main#main.pb-28.lg\\:pl-rail"
    assert_select BRIDGE, 0
  end

  test "ADR-0086 §4.2 — the direction has no app of its own: no bridge element, even through a shell" do
    sign_in_as create_school_admin

    get school_admin_classrooms_path, headers: { "User-Agent" => TEACHER_APP }

    assert_response :ok
    assert_select "header", 0
    assert_select BRIDGE, 0
  end
end
