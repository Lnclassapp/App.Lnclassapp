require "application_system_test_case"

# PR-06, ADR-0055, UDR-0041: a teacher changes the PIN in the modal (422 in the modal first, every PIN field emptied);
# the session of a second browser returns to the sign-in; the new PIN signs in, the old one no longer does.
class Identity::ProfilePinTest < ApplicationSystemTestCase
  # « Mon profil » belongs to Lot A: until it is merged, a stand-in answers on profile_path, as the role homes did in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  # Like a show.html.erb, it answers in HTML even to the frame request that follows the redirect from the modal.
  unless Object.const_defined?("Identity::ProfilesController")
    Identity.const_set(:ProfilesController, Class.new(AuthenticatedController) do
      def show = render(html: "profile", layout: true, formats: :html)
    end)
  end

  def fill_in_pins(current, pin, confirmation)
    fill_in "pin_change[current_pin]", with: current
    fill_in "pin_change[pin]", with: pin
    fill_in "pin_change[pin_confirmation]", with: confirmation
    click_on "Changer mon code secret"
  end

  test "a teacher changes the PIN; the other browser is signed out; only the new PIN signs in" do
    teacher = create_teacher
    using_session(:other_device) { sign_in_as teacher }
    sign_in_as teacher

    assert_no_page_reload do
      open_in_modal edit_profile_pin_path
      within "turbo-frame#modal dialog[open]" do
        fill_in_pins "2468", "1357", "1358"

        assert_selector "#pin_change_pin_confirmation_error", text: "Les deux codes secrets ne sont pas identiques."
        %w[current_pin pin pin_confirmation].each { assert_field "pin_change[#{it}]", with: "" }
      end
    end
    within("turbo-frame#modal dialog[open]") { fill_in_pins "2468", "1357", "1357" }

    assert_current_path profile_path
    assert_toast "Votre code secret est changé."
    assert_no_selector "turbo-frame#modal dialog[open]"

    using_session(:other_device) do
      visit teacher_home_path
      assert_selector "#session-form"
    end

    sign_out
    visit new_session_path
    fill_in "session[contact]", with: teacher.contact
    fill_in "session[pin]", with: "2468"
    click_on I18n.t("identity.sessions.new.submit")
    assert_selector "[role=alert]", text: "Code secret ou numéro incorrect."

    sign_in_as teacher, pin: "1357"
    assert_current_path teacher_home_path
  end

  # PR-07: the wrong PIN that reaches the threshold locks the account, closes the session and returns to the sign-in.
  test "the failure that locks the account returns to the sign-in with the lockout message" do
    teacher = create_teacher
    sign_in_as teacher
    4.times { create_login_attempt(user: teacher) }

    open_in_modal edit_profile_pin_path
    within("turbo-frame#modal dialog[open]") { fill_in_pins "9753", "1357", "1357" }

    assert_selector "#session-form", wait: SIGN_IN_WAIT
    assert_current_path new_session_path
    assert_toast "Trop de tentatives. Réessayez à"
    visit teacher_home_path
    assert_current_path new_session_path
  end
end
