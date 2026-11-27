# Signs in through the real forms, in the browser (ADR-0050): the number first, then the PIN (chantier
# connexion-numero-d-abord), then, for a team account that has a second factor, the current TOTP code computed from the
# factory secret, sent by itself at its sixth digit.
module SystemAuthenticationHelper
  ActionDispatch::SystemTestCase.include(self)

  # bcrypt, then the first render of the arrival page: under a loaded full suite (4 lots in parallel), up to 10 s and more.
  SIGN_IN_WAIT = 20

  def sign_in_as(user, pin: "2468")
    visit new_session_path
    enter_credentials(user.contact, pin)
    assert_no_selector "#session-pin-form", wait: SIGN_IN_WAIT
    return unless user.respond_to?(:totp_secret)

    # The code leaves by itself at the sixth digit (UDR-0054 §3.6): a click on « Vérifier » could hit a page already gone.
    fill_in "second_factor[code]", with: ROTP::TOTP.new(user.totp_secret).now
    assert_no_selector "#second-factor-form", wait: SIGN_IN_WAIT
  end

  # /login: the number, « Continuer », then the PIN tapped on the 4-box keypad, which sends it at the 4th digit (UDR-0189
  # §3.6). A number kept from before (30 min) opens /login on the PIN step: « Ce n'est pas mon numéro » brings the number
  # field back first.
  def enter_credentials(contact, pin)
    stage = find("#session-form, #session-pin-form", match: :first, wait: SIGN_IN_WAIT)
    click_on I18n.t("identity.sessions.new.not_my_number") if stage[:id] == "session-pin-form"
    fill_in "session[contact]", with: contact
    click_on I18n.t("identity.sessions.new.continue")
    tap_pin pin, wait: SIGN_IN_WAIT
  end

  # The PIN tapped on the visible keypad (UDR-0189 §3.6): in « submit » mode, the form leaves at the 4th digit.
  def tap_pin(pin, wait: Capybara.default_max_wait_time)
    keypad = find("[id$='-keypad'][role=group]", visible: true, wait:)
    pin.to_s.each_char { |digit| keypad.find("button[data-digit='#{digit}']").click }
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
