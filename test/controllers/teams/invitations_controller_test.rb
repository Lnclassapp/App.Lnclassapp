require "test_helper"

# F-16, ADR-0038, UDR-0019: a team admin invites a member in the modal frame; the link shows once, in the modal,
# never in a flash; a content or field member is refused.
class Teams::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_team_member
  end

  def invitation_params(**overrides) = { invitation: { contact: "01 00 00 00 09", team_role: "content", **overrides } }

  test "a content or field member, a teacher and a student receive 403, and nothing is written" do
    [ create_team_member(team_role: "content"), create_team_member(team_role: "field"), create_teacher, create_student ].each do |user|
      sign_in_as user

      get new_teams_invitation_path, headers: { "Turbo-Frame" => "modal" }
      assert_response :forbidden
      post teams_invitations_path, params: invitation_params, as: :turbo_stream
      assert_response :forbidden
      sign_out
    end
    assert_not Orm::Invitation.exists?
  end

  test "a visitor is sent to the sign-in" do
    get new_teams_invitation_path

    assert_redirected_to new_session_path
  end

  test "the invitation form opens in the modal frame" do
    sign_in_as @admin

    get new_teams_invitation_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#invitation-modal[aria-labelledby]"
    assert_select "form#invitation-form[action='#{teams_invitations_path}'][method=post]" do
      assert_select "input[type=tel][name='invitation[contact]'][required]"
      assert_select "input[type=radio][name='invitation[team_role]']", 3
    end
    assert_select "button[type=submit][form=invitation-form]", "Créer l'invitation"
  end

  test "without a frame, the same modal opens on the shell" do
    sign_in_as @admin

    get new_teams_invitation_path

    assert_response :success
    assert_select "main#main turbo-frame#modal dialog#invitation-modal"
  end

  test "an invitation is created: toast, and the link replaces the form in the modal" do
    sign_in_as @admin

    post teams_invitations_path, params: invitation_params, as: :turbo_stream

    assert_response :success
    invitation = Orm::Invitation.sole
    assert_equal [ "team", "0100000009", "content", @admin.id ], [ invitation.kind, invitation.contact, invitation.team_role, invitation.invited_by_id ]
    assert_in_delta 72.hours.from_now, invitation.expires_at, 5.seconds
    assert_secret_response(stream: true)
    assert_select "turbo-stream[action=append][target=toasts] template", text: /Invitation créée/
    assert_select "turbo-stream[action=update][target=modal] template" do
      link = css_select("input#invitation-link[readonly]").sole["value"]
      token = link.delete_prefix("http://www.example.com/invitations/")
      assert_equal secret_digest(token), invitation.token_digest
      assert_select "p", text: "Transmettez ce lien à la personne invitée ; il expire dans 72 h."
    end
    assert_no_link_in_flash
    assert_equal 1, Orm::AuditEvent.where(action: "invitation.sent", actor_id: @admin.id).count
  end

  test "an invalid number re-renders the modal in 422 with its message and the typed values" do
    sign_in_as @admin

    post teams_invitations_path, params: invitation_params(contact: "08 11 22 33 44", team_role: "field"), headers: { "Turbo-Frame" => "modal" }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#invitation-modal"
    assert_select "#invitation_contact_error", "Saisissez un numéro ivoirien à 10 chiffres, par exemple 01 02 03 04 05."
    assert_select "input[name='invitation[contact]'][value='08 11 22 33 44']"
    assert_select "input[type=radio][name='invitation[team_role]'][value=field][checked]"
    assert_not Orm::Invitation.exists?
  end

  test "a missing role, a number that has an account, and a pending invitation are said in the modal" do
    sign_in_as @admin

    post teams_invitations_path, params: invitation_params(team_role: ""), headers: { "Turbo-Frame" => "modal" }
    assert_select "#invitation_team_role_error", "Choisissez le rôle de la personne invitée."

    post teams_invitations_path, params: invitation_params(contact: @admin.contact), headers: { "Turbo-Frame" => "modal" }
    assert_select "#invitation_contact_error", "Ce numéro a déjà un compte Lnclass."

    create_invitation(contact: "0100000009")
    post teams_invitations_path, params: invitation_params, headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "#invitation_contact_error", "Une invitation attend déjà ce numéro."
  end

  test "an expired invitation never accepted is revoked and the number invited again" do
    expired = create_invitation(contact: "0100000009", expires_at: 1.minute.ago)
    sign_in_as @admin

    post teams_invitations_path, params: invitation_params, as: :turbo_stream

    assert_response :success
    assert_not_nil expired.reload.revoked_at
    assert_equal 1, Orm::Invitation.where(contact: "0100000009", revoked_at: nil).count
  end

  test "without Turbo, the link is rendered in the page, never in a flash" do
    sign_in_as @admin

    post teams_invitations_path, params: invitation_params

    assert_response :created
    assert_secret_response
    assert_select "main#main turbo-frame#modal dialog#invitation-created-modal input#invitation-link[readonly]"
    assert_no_link_in_flash
  end

  private

  def assert_no_link_in_flash
    assert(flash.to_h.values.none? { it.to_s.include?("/invitations/") }, "le lien ne doit jamais passer par le flash")
  end
end
