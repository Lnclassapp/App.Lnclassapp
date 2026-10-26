require "application_system_test_case"

# CA-T6 (Lnclass Teacher) — UDR-0082 §3.1, §3.2, UDR-0080 §3.6. At 390 px, the teacher's header holds on one line
# without horizontal scroll: the avatar alone on the left, « Besoin d'aide ? » on the right (the switch moved into the
# panel, mvp-teacher-student). Touching the avatar opens the account panel from the left edge, which lists « Mon profil »,
# « Modifier mon code secret », « Ajouter une matière » and « Ajouter un établissement »; Escape closes it and gives the
# focus back to the avatar.
# The student's « Mon compte » (avatar panel and page /students/menu) is covered by
# test/system/identity/student_avatar_menu_test.rb and test/controllers/classroom/student_menus_controller_test.rb (lot E1).
class Identity::AccountPanelTest < ApplicationSystemTestCase
  TRIGGER = "header a[aria-controls=account_panel]".freeze

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "CA-T6: at 390 px, the teacher's avatar opens the panel from the left with its four entries, Escape closes it" do
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré")

    # La barre de l'accueil enseignant porte son propre avatar (bandeau jaune, lien vers /teachers/menu) : ces deux tests lisent
    # la <dialog> de l'en-tête du shell, sur une page sans bandeau.
    with_mobile_viewport do
      visit profile_path

      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      within("header") do
        assert_selector TRIGGER.delete_prefix("header "), visible: true
        assert_no_selector "img[src*='logo']"
        assert_no_text "Awa Traoré"
        assert_link I18n.t("shared.help_sheet.trigger"), visible: true
        assert_no_selector "button[role=switch]", visible: true
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
        assert_equal [ tn(:profile), tn("account_panel.entries.secret"), tn("account_panel.entries.add_material"),
                       tn("account_panel.entries.add_school") ], all("nav a", minimum: 4).map(&:text)
        assert_selector "button[role=switch]", visible: true
        assert_button tn(:sign_out)
      end

      panel.send_keys(:escape)
      assert_no_selector "dialog#account_panel", visible: true
      assert page.evaluate_script("document.activeElement.matches('#{TRIGGER}')"), "le focus n'est pas revenu sur l'avatar"
    end
  end

  # UDR-0054, amendement « survol » ; chantier infobulle-badges-hors-ecran. Une fois glissé, le tiroir ne garde aucun
  # transform : sinon il devient le repère des descendants en position fixe (infobulles au survol) et les décale.
  test "once open, the account panel keeps no transform" do
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré")

    # La barre de l'accueil enseignant porte son propre avatar (bandeau jaune, lien vers /teachers/menu) : ces deux tests lisent
    # la <dialog> de l'en-tête du shell, sur une page sans bandeau.
    with_mobile_viewport do
      visit profile_path
      find(TRIGGER).click
      find("dialog#account_panel[open]", visible: true)
      page.document.synchronize do
        finished = page.evaluate_script("document.getElementById('account_panel').getAnimations().every(a => a.playState === 'finished')")
        raise Capybara::ExpectationNotMet, "le panneau glisse encore" unless finished
      end

      assert_equal "none", page.evaluate_script("getComputedStyle(document.getElementById('account_panel')).transform")
    end
  end
end
