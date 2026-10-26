require "test_helper"

# CA-E1 (mvp-teacher-student, lot E1) — UDR « écrans élève sans répétition » §3.1. « /students/menu » (coque Android, bandeau de
# l'accueil) rend le panneau « Mon compte » de l'élève en page ; l'avatar de l'en-tête (autres pages) ouvre le même panneau
# en <dialog> plein écran. Même liste dans les deux cas : en-tête (avatar, nom, classe · établissement), « Mon profil »,
# « Modifier mon code secret », « Mode sombre » (interrupteur), « Se déconnecter » ; rien d'autre. Lot O2 (CA-E8) : dès lg seulement,
# « Mon établissement » après « Mon profil », et l'en-tête sans « classe · établissement ».
class Classroom::StudentMenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne 2"))
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
  end

  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)

  # Ce que le panneau montre, dans l'ordre : liens, interrupteur, déconnexion.
  def assert_account_list(scope)
    assert_select scope do
      assert_select "[role=img][aria-label='Aya Kouassi']", text: "AK"
      assert_select "p", "Aya Kouassi"
      assert_select "p", "Tle D 1 · Lycée moderne 2"
      links = css_select("#{scope} nav[aria-label='#{tn('account_panel.label')}'] a.min-h-tap")
      # CA-E8 (lot O2): « Mon établissement » is in the list too, hidden under lg (the phone list is CA-E1's), no « Ma classe ».
      assert_equal [ [ profile_path, tn(:profile) ], [ student_school_path, tn("account_panel.entries.school") ],
                     [ edit_profile_pin_path, tn("account_panel.entries.secret") ] ],
                   links.map { [ it["href"], it.text.squish ] }
      assert_select "nav li.hidden.lg\\:block a[href='#{student_school_path}']", 1
      assert_select "nav li.hidden", 1
      assert_select "nav a", 3
      # The « class · school » line shows under lg only: on a computer the header is the avatar and the name.
      assert_select "p.lg\\:hidden", "Tle D 1 · Lycée moderne 2"
      %i[student_home_path courses_path student_classroom_path student_archive_path help_path
         edit_profile_photo_path].each { assert_select "a[href='#{public_send(it)}']", 0, it.to_s }
      assert_select "[data-controller=theme] button[role=switch][aria-checked=false]", text: tn("account_panel.entries.dark_mode")
      assert_select "form[action='#{session_path}'] input[name=_method][value=delete]"
      assert_select "form[action='#{session_path}'] button[type=submit]:not(.text-error)", tn(:sign_out)
    end
  end

  test "CA-E1: the student reads « Mon compte » as a page, with the four entries and nothing else" do
    sign_in_as @student

    get student_menu_path

    assert_response :success
    assert_select "title", text: /\A#{tn('account_panel.title')}/
    assert_select "h1", tn("account_panel.title")
    assert_account_list "main #student_menu"
    # The page is the panel's content alone: no <dialog> in the main column.
    assert_select "main dialog", 0
  end

  test "CA-E1: from another page, the header avatar opens the same panel in a full-screen <dialog>, same list" do
    sign_in_as @student

    get courses_path

    assert_response :success
    assert_select "header button#avatar-menu-button[aria-haspopup=dialog][aria-controls=avatar-menu]" \
                  "[aria-label='#{tn('avatar_menu.open', name: 'Aya Kouassi')}']"
    assert_select "header dialog#avatar-menu[aria-labelledby=avatar-menu-title]" do
      assert_select "h2#avatar-menu-title", tn("account_panel.title")
      assert_select "button[aria-label='#{I18n.t('components.modal.close')}']", 1
    end
    assert_account_list "header dialog#avatar-menu"
  end

  test "CA-E1: with a photo, the panel shows it and still offers nothing more" do
    sign_in_as attach_photo(@student)

    get student_menu_path

    assert_select "main #student_menu img.ui-avatar[alt='Aya Kouassi']"
    assert_select "main #student_menu nav li a", count: 3
  end

  test "CA-E1: a teacher and the team are refused" do
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
