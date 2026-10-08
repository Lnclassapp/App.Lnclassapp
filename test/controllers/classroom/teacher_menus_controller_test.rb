require "test_helper"

# CA-T6 (app-android, Lnclass Teacher) — UDR-0082 §3.2. « /teachers/menu » renders the teacher's account panel as a
# page: the content of the header's <dialog>, which the teachers' shell opens as a modal and the site reaches without
# JavaScript. Teacher only.
class Classroom::TeacherMenusControllerTest < ActionDispatch::IntegrationTest
  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "CA-T6: the teacher reads the account panel as a page — name, school, My profile, Invite a colleague, theme, sign out" do
    sign_in_as create_teacher(school: create_school(name: "Lycée moderne 2"), first_name: "Awa", last_name: "Traoré")

    get teacher_menu_path

    assert_response :success
    assert_select "title", text: /\A#{tn('account_panel.title')}/
    assert_select "h1", tn("account_panel.title")
    assert_select "main #teacher_menu" do
      assert_select "[role=img][aria-label='Awa Traoré']", text: "AT"
      assert_select "p", "Awa Traoré"
      assert_select "p", /Lycée moderne 2/
      links = css_select("main #teacher_menu nav[aria-label='#{tn('account_panel.label')}'] li a.min-h-tap:not([aria-current])")
      assert_equal [ [ profile_path, tn(:profile) ], [ teacher_invite_path, tn("account_panel.invite") ] ],
                   links.map { [ it["href"], it.text.strip ] }
      assert_select "[data-controller=theme] button[role=switch]"
      assert_select "form[action='#{session_path}'] button[type=submit]", tn(:sign_out)
    end
    assert_select "main dialog#account_panel", 0
  end

  test "CA-T6: a student and the team are refused" do
    [ create_student, create_team_member ].each do |user|
      sign_in_as user

      get teacher_menu_path

      assert_response :forbidden
      sign_out
    end
  end

  test "without a session, the page sends to the sign-in" do
    get teacher_menu_path

    assert_redirected_to new_session_path
  end
end
