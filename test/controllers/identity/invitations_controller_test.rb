require "test_helper"

# F-16, ID-04 replaced, ADR-0038, UDR-0019: the invitation link is the only way to a team account; it works once,
# within 72 h; no public route creates a team account.
class Identity::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = create_invitation(contact: "0100000009", team_role: "content")
  end

  def acceptance_params(**overrides)
    { invitation: { last_name: "Kouassi", first_name: "Aya Marie", gender: "female", pin: "4821", pin_confirmation: "4821",
                    **overrides } }
  end

  test "the link shows the form: last name, first name(s), gender, PIN and its confirmation, never the number" do
    get invitation_path(@invitation.token)

    assert_response :success
    assert_select "form#invitation-acceptance-form[action='#{accept_invitation_path(@invitation.token)}'][method=post]" do
      assert_select "input[name='invitation[last_name]'][required]"
      assert_select "input[name='invitation[first_name]'][required]"
      assert_select "input[type=radio][name='invitation[gender]']", 2
      assert_select "input[type=password][name='invitation[pin]'][maxlength='4']"
      assert_select "input[type=password][name='invitation[pin_confirmation]']"
      assert_select "input[name*=contact], input[name*=role]", 0
    end
  end

  test "accepting creates the team account, spends the link and sends to the sign-in, second factor to enrol" do
    post accept_invitation_path(@invitation.token), params: acceptance_params

    assert_redirected_to new_session_path
    assert_equal "Votre compte est créé. Connectez-vous : la vérification en deux étapes vous sera demandée.", flash[:notice]
    user = Orm::User.find_by!(contact: "0100000009")
    assert_equal [ "team", "content", "Kouassi", "Aya Marie", "female" ],
                 [ user.role, user.team_role, user.last_name, user.first_name, user.gender ]
    assert user.authenticate_pin("4821")
    assert_not Orm::TotpCredential.exists?(user:)
    assert_equal user.id, @invitation.reload.accepted_user_id
    assert_equal 1, Orm::AuditEvent.where(action: "invitation.accepted", actor_id: user.id).count
    assert_nil cookies[:session_token].presence
  end

  test "FU-30: the page is « Créer mon compte · Lnclass », its logo leads home, « Nom » is the autofocus target" do
    get invitation_path(@invitation.token)

    assert_select "title", "Créer mon compte · Lnclass"
    assert_select "a[href='#{root_path}'][aria-label='Lnclass, accueil'] img[alt='']", 2
    assert_select "[data-autofocus-target=field]", 1
    assert_select "input[name='invitation[last_name]'][data-autofocus-target=field]:not([autofocus])"
  end

  test "FU-31: accepting keeps the number for the sign-in in the Rails session, never in the URL nor the flash" do
    post accept_invitation_path(@invitation.token), params: acceptance_params

    assert_equal "0100000009", session[:login_contact]
    assert_redirected_to new_session_path
    assert_no_match(/0100000009|01 00/, response.location)
    assert_no_match(/0100000009|01 00/, flash.to_h.values.join)
    assert_nil cookies[:session_token].presence
    assert_equal 0, Orm::Session.count

    get new_session_path

    assert_select "input[name='session[contact]'][value='01 00 00 00 09']:not([data-autofocus-target])"
    assert_select "input[name='session[pin]'][data-autofocus-target=field]:not([value])"
    assert_nil session[:login_contact]
  end

  test "FU-32: the number is used once: a reload of the sign-in page no longer shows it" do
    post accept_invitation_path(@invitation.token), params: acceptance_params
    get new_session_path

    get new_session_path

    assert_select "input[name='session[contact]']:not([value])"
    assert_select "input[name='session[contact]'][data-autofocus-target=field]"
    assert_select "input[name='session[pin]']:not([data-autofocus-target])"
  end

  test "FU-32: a school admin invitation leads to the same pre-filled sign-in" do
    invitation = create_invitation(kind: "school_staff", contact: "0500000007")

    post accept_invitation_path(invitation.token), params: acceptance_params

    assert_redirected_to new_session_path
    assert_equal "Votre compte est créé. Connectez-vous avec votre numéro et votre code secret.", flash[:notice]
    # ID-08 (ADR-0077) : une direction entrée par invitation est marquée comme telle.
    assert_equal "invitation", Orm::SchoolStaff.joins(:user).find_by!(users: { contact: "0500000007" }).joined_via
    follow_redirect!
    assert_select "input[name='session[contact]'][value='05 00 00 00 07']"
  end

  test "FU-33: an invalid form keeps nothing for the sign-in page" do
    post accept_invitation_path(@invitation.token), params: acceptance_params(last_name: "")

    assert_response :unprocessable_entity
    assert_select "input[name='invitation[last_name]'][aria-invalid=true]"
    assert_nil session[:login_contact]

    get new_session_path
    assert_select "input[name='session[contact]']:not([value])"
  end

  test "a number that got an account meanwhile keeps nothing for the sign-in page" do
    create_teacher(contact: "0100000009")

    post accept_invitation_path(@invitation.token), params: acceptance_params

    assert_response :unprocessable_entity
    assert_nil session[:login_contact]
  end

  test "a link already used does not work a second time" do
    post accept_invitation_path(@invitation.token), params: acceptance_params

    get invitation_path(@invitation.token)
    assert_response :gone
    assert_select "#invitation-expired", text: /Ce lien d'invitation n'est plus valable/
    assert_select "form#invitation-acceptance-form", 0

    post accept_invitation_path(@invitation.token), params: acceptance_params(pin: "1357", pin_confirmation: "1357")
    assert_response :unprocessable_entity
    assert_select "#invitation-expired"
    assert_equal 1, Orm::User.where(contact: "0100000009").count
  end

  test "an expired or revoked link is no longer valid" do
    expired = create_invitation(expires_at: 1.minute.ago)
    revoked = create_invitation(revoked_at: 1.hour.ago)

    [ expired, revoked ].each do |invitation|
      get invitation_path(invitation.token)
      assert_response :gone
      post accept_invitation_path(invitation.token), params: acceptance_params
      assert_response :unprocessable_entity
      assert_not Orm::User.exists?(contact: invitation.contact)
    end
  end

  test "an unknown token is a 404" do
    get invitation_path("1" * 32)
    assert_response :not_found

    post accept_invitation_path("1" * 32), params: acceptance_params
    assert_response :not_found
  end

  test "an invalid form is re-rendered in 422, each message under its field, the PIN never sent back" do
    post accept_invitation_path(@invitation.token), params: acceptance_params(first_name: "", gender: "", pin_confirmation: "1357")

    assert_response :unprocessable_entity
    assert_select "#invitation_first_name_error", "Saisissez votre ou vos prénoms."
    assert_select "#invitation_gender_error", /Choisissez votre genre./
    assert_select "#invitation_pin_confirmation_error", "Les deux codes secrets ne sont pas identiques."
    assert_select "input[name='invitation[last_name]'][value=Kouassi]"
    assert_select "input[name='invitation[pin]']:not([value])"
    assert_nil @invitation.reload.accepted_at
  end

  test "a number that got an account meanwhile is said above the form" do
    create_teacher(contact: "0100000009")

    post accept_invitation_path(@invitation.token), params: acceptance_params

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Ce numéro a déjà un compte Lnclass/
    assert_nil @invitation.reload.accepted_at
  end

  test "a sixth request in a minute receives 429 in the form" do
    get invitation_path(@invitation.token)
    4.times { post accept_invitation_path(@invitation.token), params: acceptance_params(pin_confirmation: "1357") }
    post accept_invitation_path(@invitation.token), params: acceptance_params

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.codes.rate_limited")
    assert_not Orm::User.exists?(contact: "0100000009")
  end

  test "the bootstrap invitation printed by the seed is accepted by the same screen and gives an admin" do
    Orm::Invitation.delete_all
    output = with_env("TEAM_BOOTSTRAP_CONTACT" => "0700000001") do
      capture_io { load Rails.root.join("db/seeds/identity.rb") }.first
    end
    path = output[%r{/invitations/\w+}]

    get path
    assert_response :success
    post "#{path}", params: acceptance_params

    assert_redirected_to new_session_path
    assert_equal [ "team", "admin" ], Orm::User.where(contact: "0700000001").pick(:role, :team_role)
  end

  test "no public route creates a team account: /team-signup is a 404" do
    get "/team-signup"
    assert_response :not_found
    post "/team-signup", params: { user: { contact: "0700000002" } }
    assert_response :not_found

    team_routes = Rails.application.routes.routes.map { it.defaults[:controller].to_s }
    assert_not_includes team_routes, "teams/registrations"
  end

  private

  def with_env(values)
    previous = values.keys.index_with { ENV[it] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
