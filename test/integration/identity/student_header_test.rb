require "test_helper"

# CA-1, CA-3, CA-4 (accueil-eleve) — UDR-0084 §3.1, §3.2, §3.4, §3.10, which replace UDR-0080 §3.1–3.2 for the web
# student. The header carries the Lnclass logo on the left; on the right « Besoin d'aide ? » (from 700 px), then the
# avatar alone, a button that opens the avatar menu. No light / dark switch in the header any more (UDR écrans élève §3.1,
# mvp-teacher-student): the dark mode is in the account menu. No account panel on the web any more:
# /students/menu stays for the Android app (test/controllers/classroom/student_menus_controller_test.rb). The teacher
# keeps the header of UDR-0082 (test/integration/identity/teacher_header_test.rb).
class Identity::StudentHeaderTest < ActionDispatch::IntegrationTest
  AVATAR = "button#avatar-menu-button[aria-haspopup=menu][aria-expanded=false][aria-controls=avatar-menu]".freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne 2"))
  end

  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)

  # Text of each menu item, in the order of the page.
  def menu_items = css_select("#avatar-menu [role=menuitem]").map { it.text.squish }

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
      assert_select right, "[data-controller=theme], button[role=switch]", 0
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

  test "CA-3: the avatar menu — identity, the destinations under lg, then profile, history, photo, help and sign-out" do
    sign_in_as create_student(classroom: @classroom, first_name: "Awa", last_name: "Koné")

    get student_home_path

    assert_select "header #avatar-menu[role=menu][aria-label='#{tn('account_panel.label')}'][hidden].w-72.right-0.rounded-card.shadow-pop" do
      assert_select "img, [role=img]", 1
      assert_select ".size-10[role=img][aria-label='Awa Koné']", text: "AK"
      assert_select "p", "Awa Koné"
      assert_select "p", "Tle D 1 · Lycée moderne 2"
      assert_select "div.lg\\:hidden [role=menuitem]", count: 3
      assert_select "div.lg\\:hidden a[role=menuitem][href='#{student_home_path}'][aria-current=page].bg-brand-soft", text: tn(:home)
      assert_select "div.lg\\:hidden a[role=menuitem][href='#{courses_path}']:not([aria-current]):not(.bg-brand-soft)", text: tn(:courses)
      assert_select "div.lg\\:hidden a[role=menuitem][href='#{student_classroom_path}']:not([aria-current])", text: tn(:classroom)
      assert_select "a[role=menuitem][href='#{profile_path}']", text: tn(:profile)
      assert_select "a[role=menuitem][href='#{student_archive_path}']", text: tn("avatar_menu.history")
      assert_select "a[role=menuitem][href='#{edit_profile_photo_path}']", text: tn("avatar_menu.add_photo")
      assert_select "div.min-\\[700px\\]\\:hidden button[role=menuitem][aria-controls=help-sheet][data-action='dropdown#openDialog']",
                    text: I18n.t("shared.help_sheet.trigger")
      assert_select "[role=separator] + form[action='#{session_path}'] input[name=_method][value=delete]"
      assert_select "form[action='#{session_path}'] button[role=menuitem].ui-menu-item-danger", text: tn(:sign_out)
    end
    assert_equal [ tn(:home), tn(:courses), tn(:classroom), tn(:profile), tn("avatar_menu.history"), tn("avatar_menu.add_photo"),
                   I18n.t("shared.help_sheet.trigger"), tn(:sign_out) ], menu_items
  end

  test "CA-3: with a photo, the avatar shows it, without badge, and the menu does not offer to add one" do
    student = attach_photo(create_student(classroom: @classroom, first_name: "Aya", last_name: "Koné"))
    sign_in_as student

    get student_home_path

    assert_select "#{AVATAR} img.ui-avatar[alt='Aya Koné'][src*='/photo']"
    assert_select "#{AVATAR} span[aria-hidden=true]", text: "+", count: 0
    assert_select "#avatar-menu a[href='#{edit_profile_photo_path}']", 0
    assert_not_includes menu_items, tn("avatar_menu.add_photo")
  end

  test "CA-3: on the profile page, « Mon profil » is current and no destination is" do
    sign_in_as create_student(classroom: @classroom)

    get profile_path

    assert_select "#avatar-menu a[role=menuitem][href='#{profile_path}'][aria-current=page]"
    assert_select "#avatar-menu a[role=menuitem][aria-current=page]", count: 1
  end

  test "CA-3: on « Cours », its line is current in the menu" do
    sign_in_as create_student(classroom: @classroom)

    get courses_path

    assert_select "#avatar-menu a[role=menuitem][href='#{courses_path}'][aria-current=page].bg-brand-soft"
    assert_select "#avatar-menu a[role=menuitem][href='#{student_home_path}']:not([aria-current])"
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
