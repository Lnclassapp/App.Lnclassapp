require "test_helper"

# DS-01 to DS-04, ADR-0065, UDR-0052: from the page of an active school, the team invites its management in the modal
# frame; the link shows once, in the modal; the link creates a school admin attached to that school.
class Teams::StaffInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @member = create_team_member(team_role: "field")
  end

  def invitation_params(contact: "07 99 00 00 09") = { invitation: { contact: } }

  test "DS-04: a content member, a school admin, a teacher and a student receive 403, and nothing is written" do
    [ create_team_member(team_role: "content"), create_school_admin(school: @school), create_teacher(school: @school),
      create_student ].each do |user|
      sign_in_as user

      get new_school_staff_invitation_path(@school.public_id), headers: { "Turbo-Frame" => "modal" }
      assert_response :forbidden
      post school_staff_invitations_path(@school.public_id), params: invitation_params, as: :turbo_stream
      assert_response :forbidden
      sign_out
    end
    assert_not Orm::Invitation.exists?
  end

  test "a visitor is sent to the sign-in" do
    get new_school_staff_invitation_path(@school.public_id)

    assert_redirected_to new_session_path
  end

  test "an unknown school is not found" do
    sign_in_as @member

    get new_school_staff_invitation_path("inconnu"), headers: { "Turbo-Frame" => "modal" }
    assert_response :not_found
    post school_staff_invitations_path("inconnu"), params: invitation_params, as: :turbo_stream
    assert_response :not_found
    assert_not Orm::Invitation.exists?
  end

  test "the page of an active school offers « Inviter la direction » first in its menu; an inactive or draft one does not" do
    sign_in_as @member

    get school_path(@school.public_id)
    assert_select "#school-header-actions[role=menu] a[href='#{new_school_staff_invitation_path(@school.public_id)}'][data-turbo-frame=modal]",
                  text: "Inviter la direction"
    assert_equal "Inviter la direction", css_select("#school-header-actions[role=menu] [role=menuitem]").first.text.strip

    %w[inactive draft].each do |status|
      school = create_school(status:)
      get school_path(school.public_id)
      assert_response :success
      assert_select "a[href='#{new_school_staff_invitation_path(school.public_id)}']", 0
    end
  end

  test "the invitation form opens in the modal frame and names the school" do
    sign_in_as @member

    get new_school_staff_invitation_path(@school.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#staff-invitation-modal[aria-labelledby]" do
      assert_select "h2", "Inviter la direction"
      assert_select "p", "La personne invitée verra les enseignants et le travail des élèves de Lycée Moderne de Bouaké."
    end
    assert_select "form#staff-invitation-form[action='#{school_staff_invitations_path(@school.public_id)}'][method=post]" do
      assert_select "input[type=tel][name='invitation[contact]'][required]"
      assert_select "input[type=radio]", 0
    end
    assert_select "button[type=submit][form=staff-invitation-form]", "Créer l'invitation"
  end

  test "DS-01: an invitation for this school, without position: toast, and the link replaces the form in the modal" do
    sign_in_as @member

    post school_staff_invitations_path(@school.public_id), params: invitation_params, as: :turbo_stream

    assert_response :success
    invitation = Orm::Invitation.sole
    assert_equal [ "school_staff", "0799000009", @school.id, nil, nil, @member.id ],
                 [ invitation.kind, invitation.contact, invitation.school_id, invitation.position, invitation.team_role, invitation.invited_by_id ]
    assert_in_delta 72.hours.from_now, invitation.expires_at, 5.seconds
    assert_secret_response(stream: true)
    assert_select "turbo-stream[action=append][target=toasts] template", text: /Invitation créée/
    assert_select "turbo-stream[action=update][target=modal] template" do
      assert_select "dialog#staff-invitation-created-modal p", text: "Invitation pour le 07 99 00 00 09, direction de Lycée Moderne de Bouaké."
      link = css_select("input#invitation-link[readonly]").sole["value"]
      assert_equal secret_digest(link.delete_prefix("http://www.example.com/invitations/")), invitation.token_digest
    end
    assert_no_link_in_flash
    assert_equal({ "kind" => "school_staff", "school_id" => @school.id },
                 Orm::AuditEvent.find_by!(action: "invitation.sent", actor_id: @member.id).metadata)
  end

  test "without Turbo, the link is rendered in the page, never in a flash" do
    sign_in_as create_team_member

    post school_staff_invitations_path(@school.public_id), params: invitation_params

    assert_response :created
    assert_secret_response
    assert_select "main#main turbo-frame#modal dialog#staff-invitation-created-modal input#invitation-link[readonly]"
    assert_no_link_in_flash
  end

  test "DS-02: an inactive school is refused at the head of the modal, in 422, without invitation" do
    school = create_school(status: "inactive")
    sign_in_as @member

    post school_staff_invitations_path(school.public_id), params: invitation_params, headers: { "Turbo-Frame" => "modal" }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#staff-invitation-modal [role=alert]", text: "Cet établissement n'est pas actif."
    assert_not Orm::Invitation.exists?
  end

  test "DS-02: a number that has an account, a pending invitation and a malformed number are said on the field" do
    sign_in_as @member

    post school_staff_invitations_path(@school.public_id), params: invitation_params(contact: create_teacher.contact),
                                                           headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "#invitation_contact_error", "Ce numéro a déjà un compte Lnclass."

    create_invitation(kind: "school_staff", school: @school, position: nil, contact: "0799000009")
    post school_staff_invitations_path(@school.public_id), params: invitation_params, headers: { "Turbo-Frame" => "modal" }
    assert_select "#invitation_contact_error", "Une invitation attend déjà ce numéro."

    post school_staff_invitations_path(@school.public_id), params: invitation_params(contact: "08 11 22 33 44"),
                                                           headers: { "Turbo-Frame" => "modal" }
    assert_select "#invitation_contact_error", "Saisissez un numéro ivoirien à 10 chiffres, par exemple 01 02 03 04 05."
    assert_select "input[name='invitation[contact]'][value='08 11 22 33 44']"
    assert_equal 1, Orm::Invitation.count
  end

  test "DS-03: the link says which school the account joins, then creates a school admin attached to it alone" do
    invitation = create_invitation(kind: "school_staff", school: @school, position: nil, invited_by: @member, contact: "0799000009")

    get invitation_path(invitation.token)
    assert_response :success
    assert_select "h2", "Créer votre compte de direction"
    assert_select "p.bg-info-soft", text: "Vous rejoignez Lycée Moderne de Bouaké comme direction."
    assert_select "p", text: /vérification en deux étapes/, count: 0

    post accept_invitation_path(invitation.token), params: { invitation: { last_name: "Koné", first_name: "Awa", gender: "female",
                                                                           pin: "4821", pin_confirmation: "4821" } }

    assert_redirected_to new_session_path
    assert_equal "Votre compte est créé. Connectez-vous avec votre numéro et votre PIN.", flash[:notice]
    user = Orm::User.find_by!(contact: "0799000009")
    assert_equal [ "school_admin", nil ], [ user.role, user.team_role ]
    assert_equal [ [ @school.id, @member.id ] ], Orm::SchoolStaff.where(user_id: user.id).pluck(:school_id, :invited_by_id)
    assert_equal user.id, invitation.reload.accepted_user_id
  end

  test "the link of a team invitation still announces the second factor" do
    get invitation_path(create_invitation.token)

    assert_select "h2", "Créer votre compte équipe"
    assert_select "p.bg-info-soft", text: /vérification en deux étapes/
  end

  private

  def assert_no_link_in_flash
    assert(flash.to_h.values.none? { it.to_s.include?("/invitations/") }, "le lien ne doit jamais passer par le flash")
  end
end
