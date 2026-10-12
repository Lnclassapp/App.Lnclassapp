require "test_helper"

# ADR-0082 §4.1 and §4.2: the manifest and the service worker are served by Rails' PWA controller, drawn by the Lot 0 of
# installation-pwa; their names and paths are frozen. The service worker is served from the root so its scope is "/".
class PwaRoutesTest < ActionDispatch::IntegrationTest
  def helpers = Rails.application.routes.url_helpers

  test "the manifest and the service worker are routed to the PWA controller" do
    assert_recognizes({ controller: "rails/pwa", action: "manifest", format: "json" }, "/manifest.json")
    assert_recognizes({ controller: "rails/pwa", action: "service_worker", format: "js" }, "/service-worker.js")
  end

  test "their named routes give the frozen paths" do
    assert_equal "/manifest.json", helpers.pwa_manifest_path(format: :json)
    assert_equal "/service-worker.js", helpers.pwa_service_worker_path(format: :js)
  end
end
