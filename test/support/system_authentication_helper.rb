# Signs in through the real forms, in the browser (ADR-0050): the PIN, then, for a team account
# that has a second factor, the current TOTP code computed from the factory secret, sent by itself at its sixth digit.
module SystemAuthenticationHelper
  ActionDispatch::SystemTestCase.include(self)

  # bcrypt, then the first render of the arrival page: under a loaded full suite (4 lots in parallel), up to 10 s and more.
  SIGN_IN_WAIT = 20

  def sign_in_as(user, pin: "2468")
    visit new_session_path
    fill_in "session[contact]", with: user.contact
    fill_in "session[pin]", with: pin
    click_on I18n.t("identity.sessions.new.submit")
    assert_no_selector "#session-form", wait: SIGN_IN_WAIT
    return unless user.respond_to?(:totp_secret)

    # The code leaves by itself at the sixth digit (UDR-0054 §3.6): a click on « Vérifier » could hit a page already gone.
    fill_in "second_factor[code]", with: ROTP::TOTP.new(user.totp_secret).now
    assert_no_selector "#second-factor-form", wait: SIGN_IN_WAIT
  end

  # The same DELETE as the « Se déconnecter » entry of the shell, from whatever page is open.
  def sign_out
    page.execute_script(<<~JS, session_path)
      const form = Object.assign(document.createElement("form"), { method: "post", action: arguments[0] })
      form.append(Object.assign(document.createElement("input"), { type: "hidden", name: "_method", value: "delete" }))
      document.body.append(form)
      form.requestSubmit()
    JS
    assert_current_path root_path
  end
end
