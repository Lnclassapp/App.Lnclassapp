require "test_helper"

# ADR-0032, ADR-0050: a forgotten PIN is replaced with the 8-digit recovery code handed out by a teacher or the team.
class Identity::PinResetsControllerTest < ActionDispatch::IntegrationTest
  setup { @student = create_student }

  test "the form asks for the number, the code and the new PIN twice" do
    get new_identity_pin_reset_path

    assert_response :success
    %w[contact code pin pin_confirmation].each { assert_select "input[name='pin_reset[#{it}]']" }
  end

  # The code is shown « 1234 5678 » to the teacher: typed as shown, it must fit in the field.
  test "the code field takes the code as it is shown, with its space" do
    create_pin_recovery_code(user: @student)
    get new_identity_pin_reset_path

    assert_select "input[name='pin_reset[code]'][maxlength='9']"
    post identity_pin_reset_path, params: { pin_reset: reset_params(code: "1234 5678") }
    assert_redirected_to new_session_path
  end

  test "the right code sets the new PIN and returns to the sign-in page" do
    create_pin_recovery_code(user: @student)

    post identity_pin_reset_path, params: { pin_reset: reset_params }

    assert_redirected_to new_session_path
    assert_response :see_other
    assert_equal "Votre nouveau PIN est enregistré. Connectez-vous.", flash[:notice]
    assert Orm::User.authenticate_by(contact: @student.contact, pin: "1357")
  end

  test "a wrong code re-renders the form in 422" do
    create_pin_recovery_code(user: @student)

    post identity_pin_reset_path, params: { pin_reset: reset_params(code: "87654321") }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Numéro ou code de récupération incorrect."
  end

  test "an expired code says so in the form" do
    create_pin_recovery_code(user: @student, expires_at: 1.minute.ago)

    post identity_pin_reset_path, params: { pin_reset: reset_params }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Ce code a expiré. Demandez-en un nouveau."
  end

  test "two different PINs are refused under the confirmation" do
    post identity_pin_reset_path, params: { pin_reset: reset_params(pin_confirmation: "9753") }

    assert_response :unprocessable_entity
    assert_select "#pin_reset_pin_confirmation_error", text: "Les deux PIN ne sont pas identiques."
  end

  test "a sixth attempt in a minute receives 429" do
    6.times { post identity_pin_reset_path, params: { pin_reset: reset_params(code: "87654321") } }

    assert_response :too_many_requests
  end

  private

  def reset_params(code: "12345678", pin_confirmation: "1357")
    { contact: @student.contact, code:, pin: "1357", pin_confirmation: }
  end
end
