require "application_system_test_case"

# CA-T6 (Lnclass Teacher) — UDR-0082 §3.1, §3.2, UDR-0080 §3.6. At 390 px, the teacher's header holds on one line
# without horizontal scroll: the avatar alone on the left, « Besoin d'aide ? » and the switch on the right. Touching the
# avatar opens the account panel from the left edge, which lists « Mon profil » then « Inviter un collègue »; Escape
# closes it and gives the focus back to the avatar.
# CA-19 (accueil-eleve) — UDR-0084 §3.2: on the web, the student has the avatar menu instead
# (test/system/identity/student_avatar_menu_test.rb); the panel stays as the page /students/menu, for the Android app.
class Identity::AccountPanelTest < ApplicationSystemTestCase
  TRIGGER = "header a[aria-controls=account_panel]".freeze

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "CA-T6: at 390 px, the teacher's avatar opens the panel from the left with Invite, Escape closes it" do
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré")

    with_mobile_viewport do
      visit teacher_home_path

      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      within("header") do
        assert_selector TRIGGER.delete_prefix("header "), visible: true
        assert_no_selector "img[src*='logo']"
        assert_no_text "Awa Traoré"
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
        assert_text "Awa Traoré"
        assert_equal [ tn(:profile), tn("account_panel.invite") ], all("nav a", minimum: 2).map(&:text)
        assert_selector "button[role=switch]", visible: true
        assert_button tn(:sign_out)
      end

      panel.send_keys(:escape)
      assert_no_selector "dialog#account_panel", visible: true
      assert page.evaluate_script("document.activeElement.matches('#{TRIGGER}')"), "le focus n'est pas revenu sur l'avatar"
    end
  end

  test "CA-19: at 390 px, the student's /students/menu lists the links of the avatar menu, the switch and sign-out" do
    sign_in_as create_student(classroom: create_classroom(name: "Tle D 1"), first_name: "Aya", last_name: "Kouassi")

    with_mobile_viewport do
      visit student_menu_path

      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert_no_selector "dialog#account_panel", visible: :all
      within("#student_menu") do
        assert_text "Aya Kouassi"
        assert_text "Tle D 1"
        assert_equal [ tn(:profile), tn("avatar_menu.history"), tn("avatar_menu.add_photo"), I18n.t("shared.help_sheet.trigger") ],
                     all("nav a", minimum: 4).map { it.text.squish }
        assert_selector "button[role=switch]", visible: true
        click_link tn("avatar_menu.history")
      end

      assert_current_path student_archive_path
    end
  end
end
