require "application_system_test_case"

# Chantier entree-et-accueil-eleve-allegees, UDR pavé numérique §3.2 : « Nouveau sur Lnclass » se confirme au pavé,
# en vrai navigateur. 4 cases et 10 touches, bouton gris ; au 4e chiffre l'envoi part seul ; identiques → coche puis
# inscription ; différents → « Les deux codes sont différents. » et cases vides.
class StudentEntryPinPadTest < ApplicationSystemTestCase
  ENTRY = "identity.student_entries.new".freeze

  setup do
    @classroom = create_classroom(name: "6ème 1")
    browser_errors # le journal du navigateur est partagé : on repart d'un journal vide
  end

  def reach_confirmation(pin: "2468")
    visit new_student_entry_path
    fill_in "student_entry[contact]", with: "0701020304"
    fill_in "student_entry[pin]", with: pin
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

  test "CA-3 : 2468 deux fois, la coche puis l'inscription s'ouvre sans autre geste" do
    reach_confirmation

    tap_digits 2, 4, 6, 8

    assert_selector "#signup-step-counter", wait: 10
    assert_current_path new_student_registration_path
    assert_no_js_errors
  end

  test "CA-4 : 1111 pour 2468, message d'écart visible, cases vides, bouton gris" do
    reach_confirmation

    tap_digits 1, 1, 1, 1

    assert_selector "#student-entry-mismatch", text: "Les deux codes sont différents.", visible: :visible
    assert_selector "#student-entry-pin-pad", visible: :visible
    assert_no_selector "#student-entry-pin-boxes span", text: "●"
    assert_button I18n.t("#{ENTRY}.confirm_submit"), disabled: true

    tap_digits 2, 4, 6, 8
    assert_current_path new_student_registration_path, wait: 10
    assert_no_js_errors
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
end
