require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "the shared helpers are available to every view" do
    assert_includes self.class.ancestors, ApplicationHelper
    assert_kind_of Module, HomepageHelper
  end

  test "no reload tag without a new session" do
    flash[:notice] = "Bienvenue"
    request.headers["X-Turbo-Request-Id"] = "visit"

    assert_nil document_reload_tag
  end

  test "no reload tag for a page loaded without Turbo, which already has the right CSP" do
    flash[Authentication::RELOAD_FLASH] = true

    assert_nil document_reload_tag
  end

  test "after a new session, a Turbo visit gets a full reload and keeps the flash, but not its own flag" do
    flash[Authentication::RELOAD_FLASH] = true
    request.headers["X-Turbo-Request-Id"] = "visit"
    flash[:notice] = "Bienvenue"

    assert_dom_equal '<meta name="turbo-visit-control" content="reload">', document_reload_tag
    assert_equal({ "notice" => "Bienvenue" }, flash.to_session_value["flashes"])
  end
end
