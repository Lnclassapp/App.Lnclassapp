# Chantier ci-rejeu-cible: the signup moves on by itself config.x.signup_steps_delay_ms after the last valid field
# (100 ms under test: config/environments/test.rb; unset in production, where the controller's default, 1 s, applies).
module SignupStepsHelper
  ActionDispatch::SystemTestCase.include(self)

  PRODUCTION_DELAY_MS = 1000

  # A test that proves the move does not happen waits the delay, plus a margin for a loaded machine.
  def signup_settle = ((Rails.configuration.x.signup_steps_delay_ms || PRODUCTION_DELAY_MS) / 1000.0) + 0.5

  # UDR-0135 §3.2 : la cascade s'ouvre d'abord ; « J'ai le code de ma classe › » montre le champ code (sans effet s'il est déjà là).
  def open_code
    click_on I18n.t("classroom.student_registrations.form.have_code") if page.has_link?(I18n.t("classroom.student_registrations.form.have_code"), wait: 0)
  end

  # A test that needs the timer still pending when something else happens (the server's answer) keeps the production
  # page: no delay attribute, the controller's 1 s. The server runs in this process, so the page rendered in the block has it.
  def with_production_signup_delay
    delay = Rails.configuration.x.signup_steps_delay_ms
    Rails.configuration.x.signup_steps_delay_ms = nil
    yield
  ensure
    Rails.configuration.x.signup_steps_delay_ms = delay
  end
end
