require "test_helper"

# CA-T6 (app-android, Lnclass Teacher) — UDR-0082 §3.1, §3.2, amended by UDR enseignant §3.1 and §3.4 (mvp-teacher-student).
# Below lg the teacher gets the student's header: no logo, no role badge, no colour strip, the avatar on the left opens the
# account panel (a link to /teachers/menu without JavaScript), « Besoin d'aide ? » alone on the right (the light / dark switch is in
# the panel). From lg (UDR enseignant §3.14, lot P0), the logo and « Lnclass » on the left, a yellow strip, then help and avatar on
# the right: the same markup, shown or hidden by lg: classes. The panel lists « Mon profil », « Modifier mon code secret », « Ajouter une matière », « Ajouter un
# établissement », never « Inviter un collègue ».
# The direction keeps the header it had: logo, role badge, account menu; UDR-0128 §3.4 adds « Besoin d'aide ? ».
class Identity::TeacherHeaderTest < ActionDispatch::IntegrationTest
  TRIGGER = "a[href='/teachers/menu'][data-action='modal#open'][aria-haspopup=dialog][aria-controls=account_panel]".freeze

  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)

  test "CA-T6, CA-G12: the teacher's header — avatar on the left, help on the right below lg; from lg the logo, a yellow strip, help then avatar" do
    sign_in_as create_teacher(school: create_school(name: "Lycée moderne 2"), first_name: "Awa", last_name: "Traoré")

    get teacher_home_path

    assert_response :success
    assert_select "header > div.bg-teacher.h-1.max-lg\\:hidden[aria-hidden=true]", 1
    assert_select "header .ui-badge", 0
    assert_select "header [aria-controls=account-menu]", 0
    assert_select "header > div.flex > a.hidden.lg\\:flex[href='#{teacher_home_path}']" do
      assert_select "img[src*='logo']", 1
      assert_select "span", "Lnclass"
    end
    assert_select "header > div.flex > *", count: 3 do |(_logo, left, right)|
      assert_select left, TRIGGER do
        assert_select "span[aria-hidden=true] [role=img][aria-label='Awa Traoré']", text: "AT"
        assert_select "span.sr-only", tn("account_panel.open")
      end
      assert_select right, "a[href='#{help_path}'][aria-controls=help-sheet]", text: I18n.t("shared.help_sheet.trigger")
      assert_select right, "[data-controller=theme]", 0
    end
    # The dark mode lives in the panel, not beside the avatar.
    assert_select "header dialog#account_panel [data-controller=theme] button[role=switch]", 1
    # Lot M: « Mon compte » is a full-screen <dialog>; each counted entry reads « N sur 3 » under its label.
    assert_select "header dialog#account_panel.h-dvh.w-full" do
      assert_select "p", /Lycée moderne 2/
      links = css_select("header dialog#account_panel nav[aria-label='#{tn('account_panel.label')}'] li a")
      counter = tn("account_panel.counter.under", used: 1, max: 3)
      assert_equal [ [ profile_path, tn(:profile) ], [ edit_profile_pin_path, tn("account_panel.entries.secret") ],
                     [ edit_profile_materials_path, "#{tn('account_panel.entries.add_material')} #{counter}" ],
                     [ teacher_schools_path, "#{tn('account_panel.entries.add_school')} #{counter}" ] ],
                   links.map { [ it["href"], it.text.squish ] }
      assert_select "form[action='#{session_path}'] button", tn(:sign_out)
    end
  end

  test "CA-T6: on « Mon profil », its line in the panel is marked current, « Inviter un collègue » is not in the panel" do
    sign_in_as create_teacher

    get profile_path

    assert_select "dialog#account_panel nav a[href='#{profile_path}'][aria-current=page]"
    assert_select "dialog#account_panel nav a[href='#{teacher_invite_path}']", 0
  end

  test "CA-T6: the direction keeps the logo, the role badge, the account menu and the switch from lg, and gets the help" do
    sign_in_as create_school_admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "header img[src*='logo/lnclass']", 1
    assert_select "header a span", "Lnclass"
    assert_select "header .ui-badge", text: I18n.t("shared.roles.school_admin")
    assert_select "header button[aria-haspopup=menu][aria-controls=account-menu]", 1
    assert_select "header div[data-controller=theme].max-lg\\:hidden", 1
    assert_select "header a[aria-controls=help-sheet]", 1
    assert_select "header [aria-controls=account_panel], #account_panel", 0
  end
end
