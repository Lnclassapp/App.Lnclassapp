require "test_helper"

# ADR-0084 §4.7, UDR-0080 §3.2 : les routes du chantier app-android, dessinées par le Lot 0 pour les Lots A et B ; noms et
# chemins gelés. Reconnues sans charger leurs contrôleurs, que les lots apportent.
class AppAndroidRoutesTest < ActionDispatch::IntegrationTest
  def helpers = Rails.application.routes.url_helpers

  test "the account panel of the student and the Android asset links are routed to their frozen actions" do
    Rails.application.reload_routes_unless_loaded # Rails 8 dessine les routes à la première demande
    routes = Rails.application.routes.named_routes

    assert_equal({ controller: "classroom/student_menus", action: "show" }, routes[:student_menu].defaults)
    assert_equal({ controller: "identity/asset_links", action: "show" }, routes[:android_asset_links].defaults)
    assert_equal [ "GET", { format: :json } ], [ routes[:android_asset_links].verb, routes[:android_asset_links].requirements.slice(:format) ]
  end

  test "their named routes give the frozen paths" do
    assert_equal "/students/menu", helpers.student_menu_path
    assert_equal "/.well-known/assetlinks.json", helpers.android_asset_links_path(format: :json)
  end
end
