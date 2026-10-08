require "test_helper"

# CA-7 (app-android) — UDR-0080 §3.1. The student's header has no logo: the avatar on the left opens the account panel
# (a link to /students/menu without JavaScript), « Besoin d'aide ? » and the light / dark switch on the right, at every
# width. The teacher gets the same header (UDR-0081, test/integration/identity/teacher_header_test.rb, which also checks
# that the direction keeps the header it had).
class Identity::StudentHeaderTest < ActionDispatch::IntegrationTest
  TRIGGER = "a[href='/students/menu'][data-action='modal#open'][aria-haspopup=dialog][aria-controls=account_panel]".freeze

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "CA-7: the student's header — avatar on the left, help and switch on the right, no logo, no account menu" do
    sign_in_as create_student(classroom: create_classroom(name: "Tle D 1"), first_name: "Aya", last_name: "Kouassi")

    get student_home_path

    assert_response :success
    assert_select "header img[src*='logo/lnclass']", 0
    assert_select "header", text: /Lnclass/, count: 0
    assert_select "header [aria-controls=account-menu]", 0
    assert_select "header .ui-badge", 0
    assert_select "header > div.flex > *", count: 2 do |(left, right)|
      # The trigger is named by its hidden sentence; the avatar and the name (md+) are for the eyes.
      assert_select left, TRIGGER do
        assert_select "span[aria-hidden=true] [role=img][aria-label='Aya Kouassi']", text: "AK"
        assert_select "span[aria-hidden=true] span.hidden.md\\:inline", "Aya Kouassi"
        assert_select "span.sr-only", tn("account_panel.open")
      end
      assert_select right, "a[href='#{help_path}'][aria-controls=help-sheet]", text: I18n.t("shared.help_sheet.trigger")
      assert_select right, "div[data-controller=theme]:not([class]) button[role=switch]"
    end
    assert_select "dialog#help-sheet", count: 1
  end

  test "CA-8: the panel is a drawer <dialog> named by its title, with the content of /students/menu" do
    sign_in_as create_student(classroom: create_classroom(name: "Tle D 1"), first_name: "Aya", last_name: "Kouassi")

    get student_home_path

    assert_select "header dialog#account_panel.ui-dialog.dialog-drawer[aria-labelledby=account_panel-title]" do
      assert_select "h2#account_panel-title", tn("account_panel.title")
      assert_select "p", "Aya Kouassi"
      assert_select "nav[aria-label='#{tn('account_panel.label')}'] a[href='#{profile_path}']", tn(:profile)
      assert_select "nav a[href='#{courses_path}']", tn(:courses)
      assert_select "button[role=switch]"
      assert_select "form[action='#{session_path}'] button", tn(:sign_out)
    end
  end

  test "CA-8: on the profile page, its line in the panel is marked current" do
    sign_in_as create_student(first_name: "Aya")

    get profile_path

    assert_select "dialog#account_panel nav a[href='#{profile_path}'][aria-current=page]"
    assert_select "dialog#account_panel nav a[href='#{courses_path}']:not([aria-current])"
  end
end
