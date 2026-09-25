require "test_helper"

# ADR-0051 : the browser floor never blocks; it only flags the request for the layout banner.
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  OLD_ANDROID = "Mozilla/5.0 (Linux; Android 6.0; TECNO W3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.5249.126 Mobile Safari/537.36"
  FLOOR       = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Mobile Safari/537.36"

  test "a browser below the floor is served and flagged as outdated" do
    get root_path, headers: { "User-Agent" => OLD_ANDROID }

    assert_response :ok
    assert controller.instance_variable_get(:@outdated_browser)
  end

  test "a browser at the floor is served without the flag" do
    get root_path, headers: { "User-Agent" => FLOOR }

    assert_response :ok
    assert_nil controller.instance_variable_get(:@outdated_browser)
  end

  test "the floor is Tailwind v4's, and Internet Explorer is only flagged" do
    assert_equal({ chrome: 111, safari: 16.4, firefox: 128, ie: false }, ApplicationController::SUPPORTED_BROWSERS)
  end
end
