require "test_helper"

# CA-8 (app-android) — UDR-0080 §3.2. « /students/menu » renders the student's account panel as a page: the content of
# the header's <dialog>, which the Android shell opens as a modal and the site reaches without JavaScript. Student only.
class Classroom::StudentMenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne 2"))
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "CA-8: the student reads the account panel as a page — name, classroom, Profile, Courses, theme, sign out" do
    sign_in_as @student

    get student_menu_path

    assert_response :success
    assert_select "title", text: /\A#{tn('account_panel.title')}/
    assert_select "h1", tn("account_panel.title")
    assert_select "main #student_menu" do
      assert_select "[role=img][aria-label='Aya Kouassi']", text: "AK"
      assert_select "p", "Aya Kouassi"
      assert_select "p", "Tle D 1 · Lycée moderne 2"
      assert_select "nav[aria-label='#{tn('account_panel.label')}'] li a.min-h-tap", count: 2
      assert_select "nav a[href='#{profile_path}']", tn(:profile)
      assert_select "nav a[href='#{courses_path}']", tn(:courses)
      assert_select "[data-controller=theme] button[role=switch][aria-label='#{I18n.t('shared.theme_switch.label')}']"
      assert_select "form[action='#{session_path}'] input[name=_method][value=delete]"
      assert_select "form[action='#{session_path}'] button[type=submit]", tn(:sign_out)
    end
    # The page is the panel's content alone: no second <dialog> in the main column.
    assert_select "main dialog#account_panel", 0
  end

  test "CA-8: a teacher and the team are refused" do
    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user

      get student_menu_path

      assert_response :forbidden
      sign_out
    end
  end

  test "without a session, the page sends to the sign-in" do
    get student_menu_path

    assert_redirected_to new_session_path
  end
end
