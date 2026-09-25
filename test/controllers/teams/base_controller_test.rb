require "test_helper"

# ADR-0052 : Mission Control Jobs sits behind the team area, closed until V1 authentication.
class Teams::BaseControllerTest < ActionDispatch::IntegrationTest
  test "the jobs dashboard is closed to anyone outside the team" do
    get "/teams/jobs"

    assert_redirected_to "http://www.example.com/"
  end

  test "mission control inherits the team area guard" do
    assert_equal "Teams::BaseController", MissionControl::Jobs.base_controller_class
    assert_not MissionControl::Jobs.http_basic_auth_enabled
  end
end
