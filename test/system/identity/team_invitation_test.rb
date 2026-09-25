require "application_system_test_case"

# F-16, ADR-0038, ADR-0031, UDR-0019: an admin invites in the modal (422 in the modal, then the link in the modal,
# without a page reload); in a second browser session the link is accepted, the TOTP enrolled, /teams reached.
class Identity::TeamInvitationTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  test "an admin invites a member, who accepts the link, enrols the second factor and reaches the team home" do
    sign_in_as create_team_member
    assert_current_path team_home_path

    link = nil
    assert_no_page_reload do
      open_in_modal new_teams_invitation_path

      within "turbo-frame#modal dialog[open]" do
        fill_in "invitation[contact]", with: "08 11 22 33 44"
        choose "Contenu"
        click_on "Créer l'invitation"

        assert_selector "#invitation_contact_error", text: "Saisissez un numéro ivoirien à 10 chiffres"
        fill_in "invitation[contact]", with: "01 00 00 00 09"
        click_on "Créer l'invitation"
      end

      assert_toast "Invitation créée"
      within "turbo-frame#modal dialog[open]" do
        assert_text "Transmettez ce lien à la personne invitée ; il expire dans 72 h."
        link = find_field("invitation-link", readonly: true).value
      end
    end
    assert_match %r{/invitations/[1-9A-HJ-NP-Za-km-z]{32}\z}, link

    using_session(:invitee) do
      visit link
      fill_in "invitation[last_name]", with: "Kouassi"
      fill_in "invitation[first_name]", with: "Aya Marie"
      choose "Féminin"
      assert_no_page_reload do
        fill_in "invitation[pin]", with: "4821"
        fill_in "invitation[pin_confirmation]", with: "1357"
        click_on "Créer mon compte"

        assert_selector "#invitation_pin_confirmation_error", text: "Les deux PIN ne sont pas identiques."
      end
      assert_field "invitation[last_name]", with: "Kouassi"
      fill_in "invitation[pin]", with: "4821"
      fill_in "invitation[pin_confirmation]", with: "4821"
      click_on "Créer mon compte"

      assert_selector "#session-form", wait: SIGN_IN_WAIT
      assert_toast "Votre compte est créé."
      fill_in "session[contact]", with: "0100000009"
      fill_in "session[pin]", with: "4821"
      click_on I18n.t("identity.sessions.new.submit")

      secret = find("#second-factor-secret", wait: SIGN_IN_WAIT).text.delete(" ")
      fill_in "second_factor[code]", with: ROTP::TOTP.new(secret).now
      click_on I18n.t("identity.second_factor_enrollments.new.submit")
      click_on I18n.t("identity.second_factor_enrollments.backup_codes.done"), wait: SIGN_IN_WAIT

      assert_selector "main#main", wait: SIGN_IN_WAIT
      assert_current_path team_home_path

      visit link
      assert_text "Ce lien d'invitation n'est plus valable"
    end
  end
end
