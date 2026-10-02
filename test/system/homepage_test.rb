require "application_system_test_case"

# Garde-fou n° 7 : the whole chain (assets, CSP, browser) proven on an empty app.
# TR-01 : the role modals open without a page reload and lead to the right screen.
# UDR-0056 : the modals name the tab (RH-02) and the decision fits in the first screen of a small phone (RH-03).
class HomepageTest < ApplicationSystemTestCase
  SMALL_PHONE = [ 360, 640 ].freeze

  test "a visitor opens the homepage in a real browser" do
    visit root_path

    assert_selector "h1"
    assert_title "Accueil · Lnclass"
  end

  test "the browser loads the application JavaScript under the CSP" do
    visit root_path

    assert page.evaluate_script("typeof window.Turbo !== 'undefined'"), "Turbo n'a pas démarré : JavaScript bloqué ou absent"
  end

  test "a visitor opens the student then the teacher modal, and follows « Rejoindre ma classe »" do
    visit root_path

    assert_no_page_reload do
      within("#hero") { click_on "Je suis élève" }
      within("dialog#role-modal-student-hero[open]") do
        assert_title "Tu es élève ? · Lnclass"
        assert_link "Se connecter", href: new_session_path
        assert_link "Rejoindre ma classe", href: new_join_code_path
        find("button[aria-label='Fermer']").click
      end
      assert_no_selector "dialog[open]"
      assert_title "Accueil · Lnclass"

      within("#hero") { click_on "Je suis enseignant" }
      within("dialog#role-modal-teacher-hero[open]") do
        assert_title "Vous êtes enseignant ? · Lnclass"
        assert_link "Se connecter", href: new_session_path
        assert_link "Créer un compte", href: new_teacher_registration_path
        find("button[aria-label='Fermer']").click
      end
      assert_no_selector "dialog[open]"

      within("#hero") { click_on "Je suis élève" }
      within("dialog#role-modal-student-hero[open]") { click_on "Rejoindre ma classe" }
      assert_current_path new_join_code_path
    end
  end

  test "RH-03: on a 360 × 640 phone, the two entries of the hero are visible without scrolling" do
    with_device_viewport(*SMALL_PHONE) do
      visit root_path

      assert_selector "#hero button[aria-haspopup=dialog]", count: 2
      bottoms = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("#hero button[aria-haspopup=dialog]"))
          .map((button) => Math.round(button.getBoundingClientRect().bottom))
      JS
      height = page.evaluate_script("window.innerHeight")

      assert bottoms.all? { it <= height }, "les entrées du héros finissent à #{bottoms.join(' et ')} px pour #{height} px de fenêtre"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur à 360 px"
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
