require "application_system_test_case"

# Chantiers entree-et-accueil-eleve-allegees (UDR-0180 §3.2) et connexion-numero-d-abord (UDR-XXXX §3.4) : sur « Nouveau
# sur Lnclass », le code se tape une seule fois au pavé, en vrai navigateur. 4 cases et 10 touches, bouton gris ; au 4e
# chiffre l'envoi part seul ; coche puis inscription.
class StudentEntryPinPadTest < ApplicationSystemTestCase
  ENTRY = "identity.student_entries.new".freeze

  setup do
    @classroom = create_classroom(name: "6ème 1")
    browser_errors # le journal du navigateur est partagé : on repart d'un journal vide
  end

  def reach_confirmation
    visit new_student_entry_path
    fill_in "student_entry[contact]", with: "0701020304"
    click_on I18n.t("#{ENTRY}.submit")
    assert_selector "h1", text: I18n.t("#{ENTRY}.confirm_title")
  end

  def tap_digits(*digits) = digits.each { |digit| find("#student-entry-keypad button[data-digit='#{digit}']").click }

  test "CA-2 : 4 cases vides, 10 chiffres et Effacer, bouton gris ; 3 chiffres remplissent 3 cases" do
    reach_confirmation

    assert_selector "#student-entry-pin-pad", visible: :visible
    assert_no_selector "#student-entry-pin-field", visible: :visible
    assert_selector "#student-entry-pin-boxes span", count: 4
    assert_selector "#student-entry-keypad button[data-digit]", count: 10
    assert_selector "#student-entry-keypad button[aria-label='Effacer']"
    assert_button I18n.t("#{ENTRY}.confirm_submit"), disabled: true

    tap_digits 2, 4, 6

    assert_selector "#student-entry-pin-boxes span", text: "●", count: 3
    assert_selector "#student-entry-pin-status", text: "3 chiffres sur 4", visible: :all
    assert_button I18n.t("#{ENTRY}.confirm_submit"), disabled: true
    assert_no_js_errors
  end

  test "CA-9 : 2468 tapé une fois, la coche puis l'inscription s'ouvre sans autre geste" do
    reach_confirmation
    assert_selector "#student-entry-pin-pad", text: I18n.t("#{ENTRY}.confirm_hint")

    tap_digits 2, 4, 6, 8

    assert_selector "#student-entry-pin-check", text: "Code secret choisi.", visible: :all, wait: 10
    assert_selector "#signup-step-counter", wait: 10
    assert_current_path new_student_registration_path
    assert_no_js_errors
  end

  test "hors ligne : message d'alerte, les 4 chiffres gardés, le pavé rendu, le renvoi passe" do
    reach_confirmation
    page.execute_script("window.__fetch = window.fetch; window.fetch = () => Promise.reject(new TypeError('offline'))")

    tap_digits 2, 4, 6, 8

    assert_selector "#student-entry-pin-offline[role=alert]", text: "Pas de connexion. Réessaie.", visible: :visible
    assert_selector "#student-entry-pin-boxes span", text: "●", count: 4
    assert_selector "#student-entry-pin-pad:not([aria-busy])"
    assert_button I18n.t("#{ENTRY}.confirm_submit"), disabled: false

    page.execute_script("window.fetch = window.__fetch")
    click_on I18n.t("#{ENTRY}.confirm_submit")
    assert_current_path new_student_registration_path, wait: 10
  end

  test "Effacer retire le dernier chiffre ; le clavier physique marche" do
    reach_confirmation

    tap_digits 2, 4
    find("#student-entry-keypad button[aria-label='Effacer']").click
    assert_selector "#student-entry-pin-boxes span", text: "●", count: 1

    page.send_keys "4", "6", "8"
    assert_current_path new_student_registration_path, wait: 10
  end

  test "à 390 px : pas de défilement latéral, touches de 56 px au moins" do
    with_mobile_viewport do
      reach_confirmation

      assert_no_horizontal_scroll
      height = page.evaluate_script("document.querySelector('#student-entry-keypad button').getBoundingClientRect().height")
      assert_operator height, :>=, 56
    end
    assert_no_js_errors
  end

  private

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end

  # Un 422 attendu est journalisé par Chrome comme ressource en échec, pas comme erreur JavaScript.
  def assert_no_js_errors
    errors = browser_errors.reject { it.include?("Failed to load resource") }

    assert_empty errors, "erreurs JavaScript :\n#{errors.join("\n")}"
  end

  def browser_errors
    page.driver.browser.logs.get(:browser).select { it.level == "SEVERE" }.map(&:message)
  end
end
