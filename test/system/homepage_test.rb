require "application_system_test_case"

# Garde-fou n° 7 : the whole chain (assets, CSP, browser) proven on an empty app.
# TR-01 : the role modals open without a page reload and lead to the right screen.
# Chantier mvp-teacher-student, lot F (UDR-0059) : la page d'accueil publique tient sur un écran (CA-A1), texte à gauche
# et photo à droite sur ordinateur, la feuille mordant sur la photo (CA-A3). Le contenu et le drapeau se prouvent en test de contrôleur.
class HomepageTest < ApplicationSystemTestCase
  PHONES = [ [ 390, 844 ], [ 320, 568 ] ].freeze

  test "a visitor opens the homepage in a real browser" do
    visit root_path

    assert_selector "h1"
    assert_title "Accueil · Lnclass"
  end

  test "the browser loads the application JavaScript under the CSP" do
    visit root_path

    assert page.evaluate_script("typeof window.Turbo !== 'undefined'"), "Turbo n'a pas démarré : JavaScript bloqué ou absent"
  end

  # Chantier entree-eleve-unifiee (CA-1) et UDR-0189 §3.8 (2026-11-27) : « Je suis élève » et « Enseignant(e) » mènent
  # chacun droit à leur entrée, numéro d'abord, sans fenêtre ; un numéro sans compte ouvre l'inscription enseignant sur le code.
  test "« Enseignant(e) » leads to /teacher, number first; « Je suis élève » to the student entry" do
    visit root_path
    click_on "Je suis élève"
    assert_current_path new_student_entry_path
    assert_field "student_entry[contact]"
    # Chantier connexion-numero-d-abord : le numéro d'abord, le code à l'écran suivant.
    assert_no_field "student_entry[pin]"

    visit root_path

    click_on "Enseignant(e)"
    assert_current_path new_teacher_entry_path
    assert_selector "h1", text: "Je suis enseignant(e)"
    assert_no_field "session[pin]"
    fill_in "session[contact]", with: "05 01-02a03 04"
    assert_field "session[contact]", with: "0501020304"
    click_on I18n.t("identity.sessions.new.continue")
    assert_selector "#teacher-registration-number", text: "05 01 02 03 04"
    assert_selector "#teacher-registration-pin-pad", visible: :visible
  end

  # CA-A1 : à 390 px et à 320 × 568, photo, slogan, vague, pastille et deux entrées tiennent sans défiler, sans déborder.
  # Drapeau « Espace établissement » allumé : le pire cas, avec un lien de plus sous les deux entrées.
  test "CA-A1: on a 390 px phone and on a 320 × 568 phone, the page holds on one screen, the school space link included" do
    pilot_flags!(school_space_enabled: true)

    PHONES.each do |width, height|
      with_device_viewport(width, height) do
        visit root_path

        assert_selector "button[aria-haspopup=dialog]", count: 1
        assert_selector "a[id^=role-entry-]", count: 2
        fit = page.evaluate_script(<<~JS)
          (() => {
            const bottom = (selector) => Math.round(document.querySelector(selector).getBoundingClientRect().bottom)
            return {
              height: window.innerHeight,
              scrollHeight: document.documentElement.scrollHeight,
              overflowX: document.documentElement.scrollWidth - document.documentElement.clientWidth,
              entries: Array.from(document.querySelectorAll("button[aria-haspopup=dialog], a[id^=role-entry-]")).map((b) => Math.round(b.getBoundingClientRect().bottom)),
              photoHeight: Math.round(document.querySelector("main img").getBoundingClientRect().height),
              pill: bottom("[role=note]"), title: bottom("h1")
            }
          })()
        JS
        size = "#{width} × #{height}"

        assert_operator fit["scrollHeight"], :<=, fit["height"], "la page défile à #{size} : #{fit['scrollHeight']} px pour #{fit['height']} px"
        assert fit["entries"].all? { it <= fit["height"] }, "les entrées finissent à #{fit['entries'].join(' et ')} px à #{size}"
        assert_equal 0, fit["overflowX"], "la page déborde en largeur à #{size}"
        assert_operator fit["photoHeight"], :>=, 200, "la photo est écrasée à #{size} : #{fit['photoHeight']} px"
        assert_operator fit["pill"], :<=, fit["title"], "la pastille passe sous le titre à #{size}"
      end
    end
  end

  # CA-A3 : sur ordinateur, texte à gauche, photo à droite, un seul écran ; la feuille, à bord droit, ne cache rien de la photo
  # (retouche du porteur, 2026-11-12 : l'élève de gauche doit être entier).
  test "CA-A3: on a computer, the text is on the left, the photo on the right, on one screen, the sheet hiding nothing of the photo" do
    with_mobile_viewport([ 1440, 900 ]) do
      visit root_path

      layout = page.evaluate_script(<<~JS)
        (() => {
          const box = (selector) => document.querySelector(selector).getBoundingClientRect()
          return {
            sheetRight: box("#home-sheet").right, sheetRadius: getComputedStyle(document.querySelector("#home-sheet")).borderTopRightRadius,
            photoLeft: box("main img").left, photoRight: box("main img").right,
            titleRight: box("h1").right, scrollHeight: document.documentElement.scrollHeight, height: window.innerHeight,
            width: window.innerWidth
          }
        })()
      JS

      assert_operator layout["titleRight"], :<=, layout["sheetRight"], "le titre n'est pas dans la feuille de gauche"
      assert_operator layout["sheetRight"], :<=, layout["width"] / 2 + 150, "la feuille n'est pas à gauche"
      assert_operator layout["sheetRight"], :<=, layout["photoLeft"] + 1, "la feuille cache le bord gauche de la photo"
      assert_equal "0px", layout["sheetRadius"], "la feuille garde un bord arrondi sur ordinateur"
      assert_operator layout["photoRight"], :>=, layout["width"] - 1, "la photo n'atteint pas le bord droit"
      assert_operator layout["scrollHeight"], :<=, layout["height"], "la page défile sur ordinateur"
      assert_selector "#matieres", visible: :visible
      assert_no_selector "header, footer", visible: :all
      assert_link "Enseignant(e)", href: new_teacher_entry_path
    end
  end

  private

  # The viewport of a phone, not a window of that size: in headless Chrome, a 360 × 640 window keeps only 501 px for the
  # page. The device emulation of the DevTools protocol gives the page the whole 640 px, as the phone does.
  def with_device_viewport(width, height)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 1, mobile: true)
    yield
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
