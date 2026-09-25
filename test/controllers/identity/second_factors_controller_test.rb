require "test_helper"

# ADR-0031, ADR-0050: TOTP verification once per session, replay refused, backup codes single use.
class Identity::SecondFactorsControllerTest < ActionDispatch::IntegrationTest
  setup { @member = create_team_member }

  test "an unverified team member sees the code form" do
    sign_in_pin(@member)

    get new_identity_second_factor_path

    assert_response :success
    assert_select "input[name='second_factor[code]'][autocomplete=one-time-code]"
    assert_select "p", text: "ou un code de secours"
  end

  test "the current code verifies the session and opens the team home" do
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: current_code } }

    assert_redirected_to team_home_path
    assert_response :see_other
    assert_not_nil Orm::Session.find_by!(user: @member).second_factor_verified_at
  end

  test "a code already used is refused" do
    freeze_time do
      sign_in_as @member
      delete session_path
      sign_in_pin(@member)

      post identity_second_factor_path, params: { second_factor: { code: current_code } }

      assert_response :unprocessable_entity
      assert_select "#second_factor_code_error", text: "Code incorrect."
    end
  end

  test "a backup code is accepted once" do
    create_backup_code(user: @member, code: "Hx3kP9wQ2m")
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: "Hx3k P9wQ 2m" } }

    assert_redirected_to team_home_path

    delete session_path
    sign_in_pin(@member)
    post identity_second_factor_path, params: { second_factor: { code: "Hx3kP9wQ2m" } }

    assert_response :unprocessable_entity
  end

  test "a blank code is shown under its field" do
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: "" } }

    assert_response :unprocessable_entity
    assert_select "#second_factor_code_error"
  end

  test "too many failures lock the second factor" do
    5.times { create_login_attempt(contact: @member.contact, kind: "second_factor") }
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: current_code } }

    assert_response :too_many_requests
  end

  test "a sixth attempt in a minute receives 429" do
    sign_in_pin(@member)
    4.times { post identity_second_factor_path, params: { second_factor: { code: "000000" } } }

    post identity_second_factor_path, params: { second_factor: { code: "000000" } }
    post identity_second_factor_path, params: { second_factor: { code: "000000" } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /Trop de tentatives en une minute/
  end

  test "a verified team member is sent home" do
    sign_in_as @member

    get new_identity_second_factor_path

    assert_redirected_to team_home_path
  end

  test "a team member without a second factor is sent to the enrollment" do
    member = create_team_member(second_factor: false)
    sign_in_pin(member)

    get new_identity_second_factor_path

    assert_redirected_to new_identity_second_factor_enrollment_path
  end

  test "a visitor is sent to the sign-in page" do
    get new_identity_second_factor_path

    assert_redirected_to new_session_path
  end

  private

  def sign_in_pin(member) = post(session_path, params: { session: { contact: member.contact, pin: "2468" } })
  def current_code = ROTP::TOTP.new(@member.totp_secret).now
end
