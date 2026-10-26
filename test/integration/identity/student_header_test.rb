require "test_helper"

# CA-1, CA-3, CA-4 (accueil-eleve) — UDR-0084 §3.1, §3.2, §3.4, §3.10, which replace UDR-0080 §3.1–3.2 for the web
# student. The header carries the Lnclass logo on the left; on the right « Besoin d'aide ? » (from 700 px), then the
# avatar alone, a button that opens « Mon compte » (lot E1 of mvp-teacher-student: a full-screen <dialog>, no longer a
# dropdown). No light / dark switch in the header bar any more (UDR écrans élève §3.1): the dark mode is in « Mon compte ».
# /students/menu renders the same list as a page (test/controllers/classroom/student_menus_controller_test.rb). The teacher
# keeps the header of UDR-0082 (test/integration/identity/teacher_header_test.rb).
class Identity::StudentHeaderTest < ActionDispatch::IntegrationTest
  AVATAR = "button#avatar-menu-button[aria-haspopup=dialog][aria-controls=avatar-menu]".freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne 2"))
  end

  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)

  # Text of each entry of « Mon compte », in the order of the page: the links, the dark mode switch, sign-out.
  def menu_items = css_select("#avatar-menu nav a, #avatar-menu button[role=switch], #avatar-menu form button").map { it.text.squish }

  test "CA-1: the student's header — logo on the left; help from 700 px and the avatar alone on the right, no switch" do
    student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Koné")
    sign_in_as student

    get student_home_path

    assert_response :success
    assert_select "header > div.flex > *", count: 2 do |(left, right)|
      assert_equal [ "a", student_home_path, "Lnclass" ], [ left.name, left["href"], left.text.squish ]
      assert_select left, "img[src*='logo/lnclass'][alt='']"
      assert_select right, "a[href='#{help_path}'][aria-controls=help-sheet].hidden\\!.min-\\[700px\\]\\:inline-flex\\!.text-brand-strong\\!.font-medium\\!",
                    text: I18n.t("shared.help_sheet.trigger")
      assert_select right, "a[aria-controls=help-sheet] svg path[d^='M3.75 14.25V12a8.25']" # the headset (UDR-0084 §3.1)
      # No switch in the bar itself: the only one is inside « Mon compte ».
      assert_select right, "[data-controller=theme]", 1
      assert_select right, "dialog#avatar-menu [data-controller=theme] button[role=switch]", 1
      assert_select right, "#{AVATAR}[aria-label='#{tn('avatar_menu.open', name: 'Awa Koné')}']" do
        # CA-4: the initials and the decorative « + » badge; the colour is drawn from the public id, not the name.
        assert_select "[role=img][aria-label='Awa Koné']", text: "AK"
        assert_select "span[aria-hidden=true]", text: "+"
      end
    end
    tone = ComponentsHelper::AVATAR_TONES.values[student.public_id.sum % ComponentsHelper::AVATAR_TONES.size]
    assert_select "#{AVATAR} [role=img][class*='#{tone}']"
    # Lot E: the left menu (lg and wider) shows the same colour as the header, not one drawn from the name.
    assert_select "aside [role=img][aria-label='Awa Koné'][class*='#{tone}']"
    # The name is never written in the header, outside the menu; no role badge, no account panel, no old account menu.
    assert_select "header > div.flex > div > span", text: "Awa Koné", count: 0
    assert_select "header .ui-badge", 0
    assert_select "header dialog#account_panel", 0
    assert_select "header a[href='#{student_menu_path}']", 0
    assert_select "header [aria-controls=account-menu]", 0
    assert_select "dialog#help-sheet", count: 1
  end

  test "CA-3: « Mon compte » — identity, then profile and PIN, dark mode and sign-out; no destination" do
    sign_in_as create_student(classroom: @classroom, first_name: "Awa", last_name: "Koné")

    get student_home_path

    assert_select "header dialog#avatar-menu[aria-labelledby=avatar-menu-title]" do
      assert_select "h2#avatar-menu-title", tn("account_panel.title")
      assert_select "[role=img][aria-label='Awa Koné']", text: "AK"
      assert_select "p", "Awa Koné"
      assert_select "p", "Tle D 1 · Lycée moderne 2"
      assert_select "nav a[href='#{profile_path}']", text: tn(:profile)
      assert_select "nav a[href='#{edit_profile_pin_path}']", text: tn("account_panel.entries.secret")
      [ student_home_path, courses_path, student_classroom_path, student_archive_path, edit_profile_photo_path, help_path ].each do
        assert_select "a[href='#{it}']", 0
      end
      assert_select "button[role=switch]", text: tn("account_panel.entries.dark_mode")
      assert_select "form[action='#{session_path}'] input[name=_method][value=delete]"
      assert_select "form[action='#{session_path}'] button", text: tn(:sign_out)
    end
    assert_equal [ tn(:profile), tn("account_panel.entries.secret"), tn("account_panel.entries.dark_mode"), tn(:sign_out) ], menu_items
  end

  test "CA-3: with a photo, the avatar shows it, without badge, and « Mon compte » shows it too" do
    student = attach_photo(create_student(classroom: @classroom, first_name: "Aya", last_name: "Koné"))
    sign_in_as student

    get student_home_path

    assert_select "#{AVATAR} img.ui-avatar[alt='Aya Koné'][src*='/photo']"
    assert_select "#{AVATAR} span[aria-hidden=true]", text: "+", count: 0
    assert_select "#avatar-menu img.ui-avatar[alt='Aya Koné'][src*='/photo']"
    assert_select "#avatar-menu a[href='#{edit_profile_photo_path}']", 0
  end

  test "CA-3: on the profile page, « Mon profil » is current in « Mon compte »" do
    sign_in_as create_student(classroom: @classroom)

    get profile_path

    assert_select "#avatar-menu nav a[href='#{profile_path}'][aria-current=page]"
    assert_select "#avatar-menu a[aria-current=page]", count: 1
  end

  test "CA-3: on « Cours », « Mon compte » has no line for it and none is current" do
    sign_in_as create_student(classroom: @classroom)

    get courses_path

    assert_select "#avatar-menu a[href='#{courses_path}']", 0
    assert_select "#avatar-menu a[aria-current=page]", 0
  end

  # ADR-0098 : « Modifier la classe » renomme la classe ; l'élève la lit au nom du jour, sans rien refaire.
  test "a classroom renamed by the team shows its new name on the student's home" do
    classroom = create_classroom(name: "6ème 3", school: create_school(name: "Lycée moderne 2"))
    sign_in_as create_student(classroom:)
    get student_home_path
    assert_select "p", text: "6ème 3"

    classroom.update!(name: "6ème A")
    get student_home_path

    assert_response :success
    assert_select "p", text: "6ème A"
    assert_select "p", text: "6ème 3", count: 0
  end
end
