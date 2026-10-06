require "application_system_test_case"

# UDR-0061 §3.2 à §3.8 (PRD §4, « Carte d'aide ») : « Besoin d'aide ? » ouvre une feuille ancrée en bas sur téléphone et
# une modale centrée sur ordinateur, avec la FAQ, WhatsApp et l'appel ; le focus va sur la première ligne et revient
# sur le bouton à la fermeture. Sans JavaScript, le bouton reste un lien vers /aide. Données du support : celles du
# test (config/support.yml). UDR-0066 §3.5 (amendement de l'UDR-0061 §3.3) : le pied de la carte, « Plus sur Lnclass »,
# porte « Blog » dès le premier article publié (BL-06) ; le focus va toujours sur la première ligne. Le contenu du pied
# se prouve sans navigateur (test/controllers/classroom/student_homes_controller_test.rb), la lecture de /blog sans
# détour aussi (BL-20, test/integration/communication/articles_test.rb). Amendement du 2026-10-06 : sous lg, le bouton
# quitte l'accueil ; « Besoin d'aide ? » est la première entrée du menu du compte, et le focus revient à ce menu.
class Communication::HelpSheetTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze
  TRIGGER = "a[aria-controls=help-sheet]".freeze
  ACCOUNT_MENU = "[aria-haspopup=menu][aria-controls=account-menu]".freeze

  setup { sign_in_as create_student(classroom: create_classroom) }

  def tr(key, **) = I18n.t("shared.help_sheet.#{key}", **)
  def sheet = find("dialog#help-sheet")

  # L'entrée glisse de 0,75 rem (open:animate-slide-up) : la boîte se mesure une fois l'animation finie.
  # Sur téléphone (from_menu:), « Besoin d'aide ? » s'ouvre depuis le menu du compte.
  def open_sheet(from_menu: false)
    if from_menu
      find(ACCOUNT_MENU).click
      within("#account-menu") { click_on tr("trigger") }
    else
      click_on tr("trigger")
    end
    assert_selector "dialog#help-sheet[open]", visible: true
    page.document.synchronize do
      settled = page.evaluate_script(<<~JS)
        document.getElementById("help-sheet").getAnimations().every(function (a) { return a.playState === "finished"; })
      JS
      raise Capybara::ExpectationNotMet, "la carte glisse encore" unless settled
    end
  end

  # Boîte de la <dialog>, et taille de la fenêtre, mesurées dans le navigateur.
  def geometry
    page.evaluate_script(<<~JS)
      (function () {
        var box = document.getElementById("help-sheet").getBoundingClientRect();
        return { top: box.top, bottom: box.bottom, left: box.left, right: box.right, width: box.width,
                 height: box.height, viewportWidth: window.innerWidth, viewportHeight: window.innerHeight };
      })()
    JS
  end

  def focused_text = page.evaluate_script("document.activeElement.textContent").squish
  def trigger_focused?(selector = TRIGGER) = page.evaluate_script("document.activeElement.matches('#{selector}')")

  test "on a phone, the sheet rises from the bottom, at least a quarter high, with a handle and a close button" do
    with_mobile_viewport do
      visit student_home_path
      assert_no_link tr("trigger")
      open_sheet(from_menu: true)

      box = geometry
      assert_in_delta box["viewportHeight"], box["bottom"], 1, "la feuille n'est pas ancrée en bas"
      assert_in_delta box["viewportWidth"], box["width"], 1, "la feuille ne prend pas toute la largeur"
      assert_operator box["height"], :>=, box["viewportHeight"] * 0.25, "la feuille fait moins de 25 % de la hauteur"
      assert_operator box["height"], :<=, box["viewportHeight"] * 0.9, "la feuille dépasse 90 % de la hauteur"

      within sheet do
        assert_selector "h2", text: tr("title")
        assert_selector ".sheet-handle", visible: true
        assert_selector "button[aria-label='#{I18n.t('components.modal.close')}']", visible: true
        assert_text tr("faq.title")
        assert_text tr("whatsapp.title")
        assert_text tr("call.title")
      end
    end
  end

  test "on a phone, the focus lands on « Questions fréquentes », even with « Blog » in the footer; Escape gives it back" do
    create_article
    with_mobile_viewport do
      visit student_home_path
      open_sheet(from_menu: true)

      within(sheet) { assert_link "Blog" }
      assert_match(/\A#{Regexp.escape(tr('faq.title'))}/, focused_text)

      sheet.send_keys(:escape)
      assert_no_selector "dialog#help-sheet", visible: true
      assert trigger_focused?(ACCOUNT_MENU), "le focus n'est pas revenu sur le menu du compte"
    end
  end

  test "on a computer, a centred modal opens with the same lines, and the close button gives the focus back" do
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit student_home_path
      open_sheet

      box = geometry
      assert_in_delta box["viewportWidth"] / 2.0, (box["left"] + box["right"]) / 2.0, 1, "la modale n'est pas centrée en largeur"
      assert_in_delta box["viewportHeight"] / 2.0, (box["top"] + box["bottom"]) / 2.0, 1, "la modale n'est pas centrée en hauteur"
      assert_operator box["width"], :<=, 384, "la modale n'est pas étroite (sm)"

      within sheet do
        assert_no_selector ".sheet-handle", visible: true
        assert_text tr("faq.title")
        assert_text tr("whatsapp.title")
        assert_text tr("call.title")
        find("button[aria-label='#{I18n.t('components.modal.close')}']").click
      end
      assert_no_selector "dialog#help-sheet", visible: true
      assert trigger_focused?, "le focus n'est pas revenu sur « Besoin d'aide ? »"
    end
  end

  test "the lines lead to /aide, to WhatsApp in a new tab and to a phone call" do
    visit student_home_path
    open_sheet

    within sheet do
      assert_selector "a[href='https://wa.me/2250700000000'][target=_blank][rel~=noopener]", text: tr("whatsapp.title")
      assert_selector "a[href='tel:+2250700000001']", text: tr("call.title")
      click_on tr("faq.title")
    end
    assert_current_path help_path
    assert_selector "h1", text: I18n.t("communication.help.show.title")
  end

  # UDR-0057 dans la carte (UDR-0061 §3.8) : aucune action principale (R1), trois lignes au plus (R3), une seule
  # couleur d'accent pour les ronds (R5) ; l'accueil derrière garde sa propre règle.
  test "the sheet passes the sobriety rule" do
    with_mobile_viewport do
      visit student_home_path
      assert_single_primary_action scope: "#main"
      open_sheet(from_menu: true)

      within(sheet) { assert_no_selector SobrietyAssertions::PRIMARY_ACTION }
      assert_list_capped "#help-sheet ul.divide-y"
      assert_equal 3, sheet.all("ul > li .bg-brand-soft.text-brand-strong").size
    end
  end

  # Sans JavaScript, le contrôleur ne prend pas la main : le bouton est un simple lien vers /aide.
  test "without its controller, « Besoin d'aide ? » is a plain link to /aide" do
    visit student_home_path
    page.execute_script("document.querySelector('#{TRIGGER}').removeAttribute('data-action')")

    click_on tr("trigger")
    assert_current_path help_path
  end
end
