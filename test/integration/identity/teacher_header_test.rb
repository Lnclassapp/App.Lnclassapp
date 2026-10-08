require "test_helper"

# CA-T6 (app-android, Lnclass Teacher) — UDR-0081 §3.1, §3.2. The teacher gets the student's header: no logo, no role
# badge, the avatar on the left opens the account panel (a link to /teachers/menu without JavaScript), « Besoin
# d'aide ? » and the light / dark switch on the right. The panel lists « Mon profil » then « Inviter un collègue ».
# The direction keeps the header it had: logo, role badge, account menu.
class Identity::TeacherHeaderTest < ActionDispatch::IntegrationTest
  TRIGGER = "a[href='/teachers/menu'][data-action='modal#open'][aria-haspopup=dialog][aria-controls=account_panel]".freeze

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "CA-T6: the teacher's header — avatar on the left, help and switch on the right, a panel with My profile and Invite" do
    sign_in_as create_teacher(school: create_school(name: "Lycée moderne 2"), first_name: "Awa", last_name: "Traoré")

    get teacher_home_path

    assert_response :success
    assert_select "header > div[aria-hidden=true].bg-teacher", 1
    assert_select "header img[src*='logo/lnclass']", 0
    assert_select "header .ui-badge", 0
    assert_select "header [aria-controls=account-menu]", 0
    assert_select "header > div.flex > *", count: 2 do |(left, right)|
      assert_select left, TRIGGER do
        assert_select "span[aria-hidden=true] [role=img][aria-label='Awa Traoré']", text: "AT"
        assert_select "span.sr-only", tn("account_panel.open")
      end
      assert_select right, "a[href='#{help_path}'][aria-controls=help-sheet]", text: I18n.t("shared.help_sheet.trigger")
      assert_select right, "div[data-controller=theme]:not([class]) button[role=switch]"
    end
    assert_select "header dialog#account_panel.dialog-drawer" do
      assert_select "p", /Lycée moderne 2/
      links = css_select("header dialog#account_panel nav[aria-label='#{tn('account_panel.label')}'] li a")
      assert_equal [ [ profile_path, tn(:profile) ], [ teacher_invite_path, tn("account_panel.invite") ] ],
                   links.map { [ it["href"], it.text.strip ] }
      assert_select "form[action='#{session_path}'] button", tn(:sign_out)
    end
  end

  test "CA-T6: on « Inviter un collègue », its line in the panel is marked current" do
    sign_in_as create_teacher

    get teacher_invite_path

    assert_select "dialog#account_panel nav a[href='#{teacher_invite_path}'][aria-current=page]"
    assert_select "dialog#account_panel nav a[href='#{profile_path}']:not([aria-current])"
  end

  test "CA-T6: the direction keeps the logo, the role badge, the account menu and the switch from lg" do
    sign_in_as create_school_admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "header img[src*='logo/lnclass']", 1
    assert_select "header a span", "Lnclass"
    assert_select "header .ui-badge", text: I18n.t("shared.roles.school_admin")
    assert_select "header button[aria-haspopup=menu][aria-controls=account-menu]", 1
    assert_select "header div[data-controller=theme].max-lg\\:hidden", 1
    assert_select "header [aria-controls=account_panel], #account_panel, header [aria-controls=help-sheet]", 0
  end
end
