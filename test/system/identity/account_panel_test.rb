require "application_system_test_case"

# CA-7, CA-8 (app-android) — UDR-0080 §3.1, §3.2, §3.6. At 390 px, the student's header holds on one line without
# horizontal scroll: the avatar alone on the left, « Besoin d'aide ? » and the switch on the right. Touching the avatar
# opens the account panel from the left edge; Escape closes it and gives the focus back to the avatar.
class Identity::AccountPanelTest < ApplicationSystemTestCase
  TRIGGER = "header a[aria-controls=account_panel]".freeze

  test "CA-7, CA-8: at 390 px, the avatar opens the panel from the left, Escape closes it" do
    sign_in_as create_student(classroom: create_classroom(name: "Tle D 1"), first_name: "Aya", last_name: "Kouassi")

    with_mobile_viewport do
      visit student_home_path

      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      within("header") do
        assert_selector TRIGGER.delete_prefix("header "), visible: true
        assert_no_text "Aya Kouassi"
        assert_link I18n.t("shared.help_sheet.trigger"), visible: true
        assert_selector "button[role=switch]", visible: true
      end

      find(TRIGGER).click
      panel = find("dialog#account_panel[open]", visible: true)
      # Measured once it has slid in (motion-safe).
      page.document.synchronize do
        left = page.evaluate_script(<<~JS)
          (d => d.getAnimations().every(a => a.playState === "finished") ? d.getBoundingClientRect().left : null)(document.getElementById("account_panel"))
        JS
        raise Capybara::ExpectationNotMet, "le panneau glisse encore" if left.nil?

        assert_in_delta 0, left, 1, "le panneau ne part pas du bord gauche"
      end
      within(panel) do
        assert_text "Aya Kouassi"
        assert_text "Tle D 1"
        assert_link I18n.t("shared.navigation.profile")
        assert_link I18n.t("shared.navigation.courses")
        assert_selector "button[role=switch]", visible: true
        assert_button I18n.t("shared.navigation.sign_out")
      end

      panel.send_keys(:escape)
      assert_no_selector "dialog#account_panel", visible: true
      assert page.evaluate_script("document.activeElement.matches('#{TRIGGER}')"), "le focus n'est pas revenu sur l'avatar"
    end
  end

  # CA-T6 (Lnclass Teacher) — UDR-0081 §3.1, §3.2: the same header for the teacher; the panel lists « Mon profil » then
  # « Inviter un collègue ». The opening and closing mechanics are those checked above.
  test "CA-T6: at 390 px, the teacher's header holds on one line and the avatar opens the panel with Invite" do
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré")

    with_mobile_viewport do
      visit teacher_home_path

      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      within("header") do
        assert_no_selector "img[src*='logo']"
        assert_link I18n.t("shared.help_sheet.trigger"), visible: true
        assert_selector "button[role=switch]", visible: true
      end

      find(TRIGGER).click
      within("dialog#account_panel[open]") do
        assert_equal [ I18n.t("shared.navigation.profile"), I18n.t("shared.navigation.account_panel.invite") ],
                     all("nav a", minimum: 2).map(&:text)
        assert_button I18n.t("shared.navigation.sign_out")
      end
    end
  end
end
