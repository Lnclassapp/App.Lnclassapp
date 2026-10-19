require "application_system_test_case"

# UDR-0128 §3.4 (aide-whatsapp-message-pret) : la direction a « Besoin d'aide ? » dans son en-tête d'origine, à toute
# largeur ; à 390 px, la rangée tient sans défilement horizontal, et la carte s'ouvre avec le lien WhatsApp au message
# prêt de la direction (texte exact : test/integration/communication/help_sheet_whatsapp_message_test.rb).
class Communication::HelpSheetDirectionTest < ApplicationSystemTestCase
  setup do
    sign_in_as create_school_admin(school: create_school(name: "Collège Notre-Dame"), first_name: "Koffi", last_name: "Yao")
  end

  test "on a 390 px phone, the direction opens the help sheet from its header, without horizontal scroll" do
    with_mobile_viewport do
      visit school_admin_classrooms_path
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "l'en-tête déborde"

      within("header") { click_on I18n.t("shared.help_sheet.trigger") }

      within "dialog#help-sheet[open]" do
        link = find("a#help-sheet-whatsapp")
        assert_includes URI.decode_www_form_component(link[:href]), "Koffi Yao, membre de la direction, Collège Notre-Dame."
      end
    end
  end
end
