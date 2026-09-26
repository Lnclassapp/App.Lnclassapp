require "test_helper"

# F-07, ADR-0031, UDR-0020: a team member resets the second factor of another member, who is signed out everywhere
# and must enrol again; nobody resets their own.
class Teams::SecondFactorResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @actor = create_team_member(team_role: "field")
    @member = create_team_member(team_role: "content", first_name: "Yao", last_name: "Kouassi")
    create_backup_code(user: @member)
    create_login_session(user: @member)
  end

  def reset(user, **options) = post teams_member_second_factor_reset_path(user.public_id), **options

  test "the second factor of another member is reset: toast, the result replaced, the member signed out" do
    sign_in_as @actor

    reset @member, as: :turbo_stream

    assert_response :success
    assert_not Orm::TotpCredential.exists?(user_id: @member.id)
    assert_not Orm::BackupCode.exists?(user_id: @member.id)
    assert_not Orm::Session.exists?(user_id: @member.id)
    assert Orm::Session.exists?(user_id: @actor.id)
    assert_equal 1, Orm::AuditEvent.where(action: "totp.reset", actor_id: @actor.id, subject_id: @member.id).count
    assert_select "turbo-stream[action=append][target=toasts] template", text: /Second facteur réinitialisé pour Yao Kouassi/
    assert_select "turbo-stream[action=replace][target=account-lookup-result] template" do
      assert_select "#account-second-factor", text: "Non activé"
    end
  end

  test "one's own second factor and a non-team account are refused in 403, without change" do
    sign_in_as @actor

    reset @actor, as: :turbo_stream
    assert_response :forbidden
    reset create_teacher, as: :turbo_stream
    assert_response :forbidden

    assert Orm::TotpCredential.exists?(user_id: @actor.id)
    assert_not Orm::AuditEvent.exists?(action: "totp.reset")
  end

  test "a teacher is refused, an unknown account gives 404" do
    sign_in_as create_teacher
    reset @member
    assert_response :forbidden
    sign_out

    sign_in_as @actor
    post teams_member_second_factor_reset_path("inconnu")
    assert_response :not_found
    assert Orm::TotpCredential.exists?(user_id: @member.id)
  end

  test "without Turbo, back to the search of the same number, with the notice" do
    sign_in_as @actor

    reset @member

    assert_redirected_to teams_account_lookup_path(contact: @member.contact)
    assert_response :see_other
    assert_equal "Second facteur réinitialisé pour Yao Kouassi.", flash[:notice]
  end
end
