require "test_helper"

# ADR-0031: a team account activates TOTP with a first code; the backup codes are rendered once, never stored.
class Identity::SecondFactorEnrollmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member(second_factor: false)
    post session_path, params: { session: { contact: @member.contact, pin: "2468" } }
  end

  test "the enrollment shows a QR code and the secret" do
    get new_identity_second_factor_enrollment_path

    assert_response :success
    secret = Orm::TotpCredential.find_by!(user: @member).secret
    assert_select "[role=img] svg"
    assert_select "#second-factor-secret", text: secret.scan(/.{1,4}/).join(" ")
    assert_select "input[type=hidden][name='second_factor[secret]'][value=?]", secret
  end

  test "the first code activates the second factor and renders the backup codes" do
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: current_code) }

    assert_response :success
    assert_select "li", 10
    assert_select "a[href='#{team_home_path}']", text: "J'ai noté mes codes"
    assert_not_nil Orm::TotpCredential.find_by!(user: @member).confirmed_at
    assert_not_nil Orm::Session.find_by!(user: @member).second_factor_verified_at
    assert_empty flash.to_h
  end

  # ADR-0066 §4.2, UDR-0052 §3.12: the direction enrolls like the team; « Terminé » leads to its own home.
  test "a member of the direction enrolls, and the backup codes lead to the direction home" do
    sign_out
    @member = create_school_admin(second_factor: false)
    post session_path, params: { session: { contact: @member.contact, pin: "2468" } }
    get new_identity_second_factor_enrollment_path
    assert_select "p", text: "Obligatoire pour l'équipe et la direction."

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: current_code) }

    assert_response :success
    assert_select "a[href='#{school_admin_home_path}']", text: "J'ai noté mes codes"
    get school_admin_home_path
    assert_response :success
  end

  test "under Turbo, the backup codes replace the enrollment in place" do
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: current_code) },
                                                 as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream action="replace" target="second-factor-enrollment"/, response.body)
    assert_equal 10, response.body.scan("<li").size
  end

  test "a wrong code re-renders the same QR code in 422" do
    get new_identity_second_factor_enrollment_path
    secret = Orm::TotpCredential.find_by!(user: @member).secret

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: "000000") }

    assert_response :unprocessable_entity
    assert_select "#second_factor_code_error", text: "Code incorrect."
    assert_select "#second-factor-secret", text: secret.scan(/.{1,4}/).join(" ")
    assert_select "[role=img] svg"
  end

  test "a submitted address that is not a TOTP URI draws no QR code" do
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path,
         params: { second_factor: enrollment_params(code: "000000").merge(secret_uri: "javascript:alert(1)") }

    assert_response :unprocessable_entity
    assert_select "[role=img] svg", 0
  end

  test "an enrolled team member is sent to the verification" do
    sign_out
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    get new_identity_second_factor_enrollment_path

    assert_redirected_to new_identity_second_factor_path
  end

  test "a signed-in student is sent home" do
    sign_out
    sign_in_as create_teacher

    get new_identity_second_factor_enrollment_path

    assert_redirected_to teacher_home_path
  end

  private

  def credential = Orm::TotpCredential.find_by!(user: @member)
  def current_code = ROTP::TOTP.new(credential.secret).now

  def enrollment_params(code:)
    { code:, secret: credential.secret, secret_uri: ROTP::TOTP.new(credential.secret, issuer: "Lnclass").provisioning_uri(@member.contact) }
  end
end
