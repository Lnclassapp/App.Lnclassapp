require "test_helper"

# ADR-0052 : Railway switches traffic only after /up answers 200.
class HealthCheckTest < ActionDispatch::IntegrationTest
  test "/up answers 200 without authentication" do
    get rails_health_check_path

    assert_response :ok
  end
end
