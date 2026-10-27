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

  test "a visitor opens the student then the teacher modal, and follows « Créer mon compte »" do
    visit root_path

    assert_no_page_reload do
      click_on "Je suis élève"
      within("dialog#role-modal-student-entry[open]") do
        assert_title "Tu es élève ? · Lnclass"
        assert_link "Se connecter", href: new_session_path
        assert_link "Créer mon compte", href: new_student_registration_path
        find("button[aria-label='Fermer']").click
      end
      assert_no_selector "dialog[open]"
      assert_title "Accueil · Lnclass"

      click_on "Enseignant(e)"
      within("dialog#role-modal-teacher-entry[open]") do
        assert_title "Vous êtes enseignant ? · Lnclass"
        assert_link "Se connecter", href: new_session_path
        assert_link "Créer un compte", href: new_teacher_registration_path
        find("button[aria-label='Fermer']").click
      end
      assert_no_selector "dialog[open]"

      click_on "Je suis élève"
      within("dialog#role-modal-student-entry[open]") { click_on "Créer mon compte" }
      assert_current_path new_student_registration_path
    end
  end

  # CA-A1 : à 390 px et à 320 × 568, photo, slogan, vague, pastille et deux entrées tiennent sans défiler, sans déborder.
  # Drapeau « Espace établissement » allumé : le pire cas, avec un lien de plus sous les deux entrées.
  test "CA-A1: on a 390 px phone and on a 320 × 568 phone, the page holds on one screen, the school space link included" do
    pilot_flags!(school_space_enabled: true)

    PHONES.each do |width, height|
      with_device_viewport(width, height) do
        visit root_path

        assert_selector "button[aria-haspopup=dialog]", count: 3
        fit = page.evaluate_script(<<~JS)
          (() => {
            const bottom = (selector) => Math.round(document.querySelector(selector).getBoundingClientRect().bottom)
            return {
              height: window.innerHeight,
              scrollHeight: document.documentElement.scrollHeight,
              overflowX: document.documentElement.scrollWidth - document.documentElement.clientWidth,
              entries: Array.from(document.querySelectorAll("button[aria-haspopup=dialog]")).map((b) => Math.round(b.getBoundingClientRect().bottom)),
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

  # CA-A3 : sur ordinateur, texte à gauche, photo à droite, un seul écran, la feuille mord sur la photo.
  test "CA-A3: on a computer, the text is on the left, the photo on the right, on one screen, the sheet biting on the photo" do
    with_mobile_viewport([ 1440, 900 ]) do
      visit root_path

      layout = page.evaluate_script(<<~JS)
        (() => {
          const box = (selector) => document.querySelector(selector).getBoundingClientRect()
          return {
            sheetRight: box("#home-sheet").right, photoLeft: box("main img").left, photoRight: box("main img").right,
            titleRight: box("h1").right, scrollHeight: document.documentElement.scrollHeight, height: window.innerHeight,
            width: window.innerWidth
          }
        })()
      JS

      assert_operator layout["titleRight"], :<=, layout["sheetRight"], "le titre n'est pas dans la feuille de gauche"
      assert_operator layout["sheetRight"], :<=, layout["width"] / 2 + 150, "la feuille n'est pas à gauche"
      assert_operator layout["sheetRight"], :>, layout["photoLeft"], "la feuille ne mord pas sur la photo"
      assert_operator layout["photoRight"], :>=, layout["width"] - 1, "la photo n'atteint pas le bord droit"
      assert_operator layout["scrollHeight"], :<=, layout["height"], "la page défile sur ordinateur"
      assert_selector "#matieres", visible: :visible
      assert_no_selector "header, footer", visible: :all
      click_on "Je suis élève"
      assert_selector "dialog#role-modal-student-entry[open]"
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
