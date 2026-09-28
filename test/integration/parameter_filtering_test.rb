require "test_helper"

# Garde-fou n° 6 : the phone contact, the PIN and every one-time secret never reach the logs
# (ADR-0002, ADR-0025, ADR-0031, ADR-0032, ADR-0038, ADR-0041).
class ParameterFilteringTest < ActiveSupport::TestCase
  test "contact and PIN are filtered from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("session" => { "contact" => "0700000000", "pin" => "1234", "pin_confirmation" => "1234", "classroom" => "6e A" })

    assert_equal({ "contact" => "[FILTERED]", "pin" => "[FILTERED]", "pin_confirmation" => "[FILTERED]", "classroom" => "6e A" }, filtered["session"])
  end

  test "second factor, recovery, invitation and join secrets are filtered" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    secrets = %w[new_pin code otp backup_code token join_code].index_with("secret")

    assert_equal secrets.transform_values { "[FILTERED]" }, filter.filter(secrets)
  end

  test "the TOTP secret carried by the enrollment form is filtered" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("second_factor" => { "code" => "123456", "secret" => "JBSWY3DP", "secret_uri" => "otpauth://totp/x" })

    assert_equal({ "code" => "[FILTERED]", "secret" => "[FILTERED]", "secret_uri" => "[FILTERED]" }, filtered["second_factor"])
  end

  test "the student number never reaches the logs, nested included (ADR-0065)" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("student_number" => "12345678A", "student_lookup" => { "student_number" => "12345678A" },
                             "join" => { "student_number" => "12345678A", "last_name" => "Koné" })

    assert_equal({ "student_number" => "[FILTERED]", "student_lookup" => { "student_number" => "[FILTERED]" },
                   "join" => { "student_number" => "[FILTERED]", "last_name" => "Koné" } }, filtered)
  end
end
