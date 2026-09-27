require "test_helper"

# ADR-0051 : no browser is refused; below the floor, a non-blocking banner.
class SupportedBrowsersTest < ActionDispatch::IntegrationTest
  OLD_ANDROID = "Mozilla/5.0 (Linux; Android 6.0; TECNO W3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.5249.126 Mobile Safari/537.36"
  FLOOR       = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Mobile Safari/537.36"

  test "a browser below the floor gets the page and a warning, never a 406" do
    get root_path, headers: { "User-Agent" => OLD_ANDROID }

    assert_response :ok
    assert_select ".outdated-browser", text: I18n.t("layouts.outdated_browser")
  end

  test "a browser at the floor gets the page without warning" do
    get root_path, headers: { "User-Agent" => FLOOR }

    assert_response :ok
    assert_select ".outdated-browser", count: 0
  end

  test "a request without User-Agent gets the page without warning" do
    get root_path, headers: { "User-Agent" => "" }

    assert_response :ok
    assert_select ".outdated-browser", count: 0
  end

  test "the static 406 page is gone" do
    assert_not File.exist?(Rails.public_path.join("406-unsupported-browser.html"))
  end
end
