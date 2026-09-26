require "application_system_test_case"

# ID-15, F-07, ADR-0031, ADR-0032, UDR-0020: the team looks up a number, issues a recovery code shown once in the modal,
# then resets the second factor of another member — all without a page reload.
class Teams::AccountUnlockTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands. A merged
  # controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) {
      def show = render(html: "home", layout: true, formats: :html)
    })
  end

  setup do
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def look_up(contact)
    fill_in "contact", with: contact
    click_on "Rechercher"
  end

  test "look up a number, issue a code in the modal, reset another member's second factor, without a page reload" do
    student = create_student(classroom: create_classroom(name: "3ème 4"), contact: "0511223344", first_name: "Awa", last_name: "Koné")
    member = create_team_member(team_role: "content", contact: "0700000077", first_name: "Yao", last_name: "Kouassi")
    visit teams_account_lookup_path

    assert_no_page_reload do
      look_up "05 11 22 33 44"
      within("#account-lookup-result") { assert_text "Awa Koné" }
      assert_selector "#account-lookup-result dd", text: "3ème 4"
      assert_current_path teams_account_lookup_path(contact: "05 11 22 33 44")

      click_on "Générer un code de récupération"
      within "turbo-frame#modal dialog#pin-recovery-code-modal[open]" do
        assert_text "Pour Awa Koné"
        code = find("#pin-recovery-code").text.delete(" ")
        assert_equal secret_digest(code), Orm::PinRecoveryCode.find_by!(user: student).code_digest
        click_on "Fermer"
      end
      assert_toast "Code de récupération généré."
      assert_no_selector "dialog#pin-recovery-code-modal[open]"

      look_up member.contact
      within("#account-lookup-result") { assert_selector "#account-second-factor", text: "Activé" }
      click_on "Réinitialiser le second facteur"
      within("dialog#reset-second-factor-modal[open]") { click_on "Réinitialiser" }

      assert_toast "Second facteur réinitialisé pour Yao Kouassi."
      assert_selector "#account-second-factor", text: "Non activé"
    end
    assert_not Orm::TotpCredential.exists?(user_id: member.id)
  end
end
