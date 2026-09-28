require "test_helper"

# UDR-0051, AP-01, AP-08: every PIN field of the application renders the reveal button, hidden until the password-reveal
# controller shows it, with the attributes of the PIN kept (type, autocomplete, inputmode, maxlength).
class PinRevealFieldsTest < ActionDispatch::IntegrationTest
  def assert_revealable(name, autocomplete:)
    id = css_select("input[name='#{name}']").first&.[]("id")

    assert id, "champ #{name} absent"
    assert_select "div[data-controller=password-reveal] > input[name='#{name}'][type=password][inputmode=numeric]" \
                  "[maxlength='4'][autocomplete=#{autocomplete}][data-password-reveal-target=input]"
    assert_select "div[data-controller=password-reveal] > input[name='#{name}'] + " \
                  "button[type=button][hidden][aria-pressed=false][aria-controls=#{id}][aria-label='Afficher le code']"
  end

  test "sign-in: the PIN" do
    get new_session_path

    assert_revealable "session[pin]", autocomplete: "current-password"
  end

  test "sign-in failed in 422: the PIN comes back empty, masked, with its button" do
    student = create_student
    post session_path, params: { session: { contact: student.contact, pin: "1357" } }

    assert_response :unprocessable_content
    assert_revealable "session[pin]", autocomplete: "current-password"
    assert_select "input[name='session[pin]']:not([value])"
  end

  test "team invitation: the PIN and its confirmation" do
    get invitation_path(create_invitation.token)

    assert_revealable "invitation[pin]", autocomplete: "new-password"
    assert_revealable "invitation[pin_confirmation]", autocomplete: "new-password"
  end

  test "teacher sign-up: the PIN and its confirmation" do
    get new_teacher_registration_path

    assert_revealable "teacher_registration[pin]", autocomplete: "new-password"
    assert_revealable "teacher_registration[pin_confirmation]", autocomplete: "new-password"
  end

  test "student sign-up by classroom code: the PIN and its confirmation" do
    create_classroom(join_code: "kfm37")
    get join_classroom_path("kfm37")

    assert_revealable "join[pin]", autocomplete: "new-password"
    assert_revealable "join[pin_confirmation]", autocomplete: "new-password"
  end

  test "forgotten PIN: the new PIN and its confirmation" do
    get new_identity_pin_reset_path

    assert_revealable "pin_reset[pin]", autocomplete: "new-password"
    assert_revealable "pin_reset[pin_confirmation]", autocomplete: "new-password"
  end

  test "profile, change my PIN: the current PIN, the new one and its confirmation" do
    sign_in_as create_teacher
    get edit_profile_pin_path, headers: { "Turbo-Frame" => "modal" }

    assert_revealable "pin_change[current_pin]", autocomplete: "current-password"
    assert_revealable "pin_change[pin]", autocomplete: "new-password"
    assert_revealable "pin_change[pin_confirmation]", autocomplete: "new-password"
  end

  test "profile, change my number: the current PIN" do
    sign_in_as create_student(classroom: create_classroom)
    get edit_profile_contact_path, headers: { "Turbo-Frame" => "modal" }

    assert_revealable "contact_change[current_pin]", autocomplete: "current-password"
  end

  # A new PIN field written without the option would slip through the tests above: the sources are read instead.
  test "every password field of the views asks for the reveal button" do
    calls = Rails.root.glob("app/views/**/*.erb").flat_map do |path|
      path.read.scan(/ui_field\s+\w+,\s*:\w+,\s*as: :password.*?%>/m).map { [ path.relative_path_from(Rails.root), it ] }
    end

    assert_operator calls.size, :>=, 14
    calls.each { |path, call| assert_includes call, "reveal: true", "#{path} : #{call.lines.first.strip}" }
  end
end
