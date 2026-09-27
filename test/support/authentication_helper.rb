# Signs in through the real endpoints (ADR-0050): the PIN, then, for a team account that has a
# second factor, the current TOTP code computed from the factory secret (`member.totp_secret`).
module AuthenticationHelper
  ActionDispatch::IntegrationTest.include(self)

  def sign_in_as(user, pin: "2468")
    post session_path, params: { session: { contact: user.contact, pin: } }
    return unless user.respond_to?(:totp_secret)

    post identity_second_factor_path, params: { second_factor: { code: ROTP::TOTP.new(user.totp_secret).now } }
  end

  def sign_out
    delete session_path
  end
end
