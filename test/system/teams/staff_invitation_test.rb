require "application_system_test_case"

# DS-01, DS-03, ADR-0065, UDR-0052: from the page of an active school, a team member invites its management in the
# modal (a refusal in the modal, then the link, without a page reload); in a second browser session, on a phone, the link
# creates the account, which signs in with its number and PIN alone and reads its school on its profile.
class Teams::StaffInvitationTest < ApplicationSystemTestCase
  test "the team invites the management of a school, who creates the account and signs in without a second factor" do
    school = create_school(name: "Lycée Moderne de Bouaké")
    teacher = create_teacher(school:)
    sign_in_as create_team_member(team_role: "field")
    visit school_path(school.public_id)

    link = nil
    assert_no_page_reload do
      click_menu_action "#school_header", "Inviter la direction"

      within "turbo-frame#modal dialog[open]" do
        assert_text "La personne invitée verra les enseignants et le travail des élèves de Lycée Moderne de Bouaké."
        fill_in "invitation[contact]", with: teacher.contact
        click_on "Créer l'invitation"

        assert_selector "#invitation_contact_error", text: "Ce numéro a déjà un compte Lnclass."
        fill_in "invitation[contact]", with: "07 99 00 00 09"
        click_on "Créer l'invitation"
      end

      assert_toast "Invitation créée"
      within "turbo-frame#modal dialog[open]" do
        assert_text "Invitation pour le 07 99 00 00 09, direction de Lycée Moderne de Bouaké."
        link = find_field("invitation-link", readonly: true).value
      end
    end
    assert_match %r{/invitations/[1-9A-HJ-NP-Za-km-z]{32}\z}, link

    using_session(:invitee) do
      with_mobile_viewport do
        visit link
        assert_text "Vous rejoignez Lycée Moderne de Bouaké comme direction."
        assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile en largeur"
        fill_in "invitation[last_name]", with: "Koné"
        fill_in "invitation[first_name]", with: "Awa"
        choose "Féminin"
        fill_in "invitation[pin]", with: "4821"
        fill_in "invitation[pin_confirmation]", with: "4821"
        click_on "Créer mon compte"

        assert_selector "#session-form", wait: SIGN_IN_WAIT
        assert_toast "Votre compte est créé. Connectez-vous avec votre numéro et votre code secret."
        # UDR-0054 §3.8: « Se connecter » arrives with the number filled in, the focus on the PIN.
        assert_field "session[contact]", with: "07 99 00 00 09"
        assert_selector "#session_pin:focus"
        fill_in "session[pin]", with: "4821"
        click_on I18n.t("identity.sessions.new.submit")

        assert_no_selector "#session-form", wait: SIGN_IN_WAIT
        assert_no_selector "#second-factor-form"
        assert_no_selector "#second-factor-secret"

        visit profile_path
        within "#profile_information" do
          assert_text "Établissement"
          assert_text "Lycée Moderne de Bouaké"
          assert_no_text "Compte en attente"
        end
        assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile en largeur"
      end
    end
  end
end
