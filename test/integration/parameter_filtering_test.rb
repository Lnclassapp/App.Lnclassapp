require "test_helper"

# Garde-fou n° 6 : the phone contact and the PIN never reach the logs (ADR-0002, ADR-0025).
class ParameterFilteringTest < ActiveSupport::TestCase
  test "contact and PIN are filtered from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("session" => { "contact" => "0700000000", "pin" => "1234", "pin_confirmation" => "1234", "classroom" => "6e A" })

    assert_equal({ "contact" => "[FILTERED]", "pin" => "[FILTERED]", "pin_confirmation" => "[FILTERED]", "classroom" => "6e A" }, filtered["session"])
  end
end
