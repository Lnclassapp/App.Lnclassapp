require "test_helper"

# CA-8 (app-android) — UDR-0080 §3.2. « /students/menu » renders the student's account panel as a page, which the
# Android shell opens as a modal. Student only. CA-19 (accueil-eleve) — UDR-0084 §3.2: the web student has the avatar
# menu instead; the page keeps the panel, with the links 3 to 7 of that menu: « Mon profil », « Mon historique »,
# « Ajouter ma photo » (without a photo), « Besoin d'aide ? », then the switch and « Se déconnecter ».
class Classroom::StudentMenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne 2"))
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "CA-8, CA-19: the student reads the account panel as a page — name, classroom, the links of the menu, theme, sign out" do
    sign_in_as @student

    get student_menu_path

    assert_response :success
    assert_select "title", text: /\A#{tn('account_panel.title')}/
    assert_select "h1", tn("account_panel.title")
    assert_select "main #student_menu" do
      assert_select "[role=img][aria-label='Aya Kouassi']", text: "AK"
      assert_select "p", "Aya Kouassi"
      assert_select "p", "Tle D 1 · Lycée moderne 2"
      links = css_select("nav[aria-label='#{tn('account_panel.label')}'] li a.min-h-tap")
      assert_equal [ [ profile_path, tn(:profile) ], [ student_archive_path, tn("avatar_menu.history") ],
                     [ edit_profile_photo_path, tn("avatar_menu.add_photo") ], [ help_path, I18n.t("shared.help_sheet.trigger") ] ],
                   links.map { [ it["href"], it.text.squish ] }
      assert_select "nav a[href='#{courses_path}']", 0
      assert_select "[data-controller=theme] button[role=switch][aria-label='#{I18n.t('shared.theme_switch.label')}']"
      assert_select "form[action='#{session_path}'] input[name=_method][value=delete]"
      assert_select "form[action='#{session_path}'] button[type=submit]", tn(:sign_out)
    end
    # The page is the panel's content alone: no second <dialog> in the main column.
    assert_select "main dialog#account_panel", 0
  end

  test "CA-19: with a photo, the page does not offer to add one" do
    sign_in_as attach_photo(@student)

    get student_menu_path

    assert_select "main #student_menu img.ui-avatar[alt='Aya Kouassi']"
    assert_select "main #student_menu nav a[href='#{edit_profile_photo_path}']", 0
    assert_select "main #student_menu nav li a", count: 3
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
