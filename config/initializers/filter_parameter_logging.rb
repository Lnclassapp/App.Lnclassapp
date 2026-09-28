# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :contact, /\Apin/, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # PIN, recovery and backup codes, second factor, invitation token, join code (ADR-0031, 0032, 0038, 0041, 0050).
  :pin, :pin_confirmation, :new_pin, :code, :backup_code, :join_code,
  # MENA student number of a minor (ADR-0065).
  :student_number
]
