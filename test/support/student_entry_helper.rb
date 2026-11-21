# Chantier entree-eleve-unifiee : « Je suis élève » passe d'abord par l'entrée (numéro et code secret). Un nouveau numéro
# confirme son code puis arrive sur l'inscription, numéro et code gardés (ADR-0141).
module StudentEntryHelper
  ActionDispatch::SystemTestCase.include(self)

  ENTRY = "identity.student_entries.new".freeze

  # Sur la page d'entrée ouverte (/student ou /c/<jeton>) : numéro inconnu, code, puis sa confirmation.
  def pass_student_entry(contact: "0701020304", pin: "4821")
    fill_in "student_entry[contact]", with: contact
    fill_in "student_entry[pin]", with: pin
    click_on I18n.t("#{ENTRY}.submit")
    assert_selector "h1", text: I18n.t("#{ENTRY}.confirm_title")
    # Pavé numérique (UDR pavé §3.2) : au 4e chiffre l'envoi part seul.
    pin.each_char { |key| find("#student-entry-keypad button[data-digit='#{key}']").click }
    assert_selector "#signup-entry-number"
  end
end
