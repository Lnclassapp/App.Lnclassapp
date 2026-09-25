require "test_helper"

class HomepageControllerTest < ActionDispatch::IntegrationTest
  test "the homepage is served at the root" do
    get root_url

    assert_response :success
  end
end
