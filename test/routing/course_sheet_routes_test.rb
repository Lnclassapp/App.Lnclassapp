require "test_helper"

# Contenu-en-blocs (#318), Lot 0 : la route de la fiche de cours est posée, nom et chemin gelés. Elle est reconnue sans
# charger son contrôleur, que le Lot B apporte.
class CourseSheetRoutesTest < ActionDispatch::IntegrationTest
  # Première route reconnue, sans charger son contrôleur (les routes se dessinent à la première lecture).
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action, :course_slug, :slug) }
    nil
  end

  test "GET /courses/:course_slug/fiche mène à catalog/course_sheets#show, sous le nom course_sheet" do
    assert_equal({ controller: "catalog/course_sheets", action: "show", course_slug: "thales" }, first_match("/courses/thales/fiche"))
    assert_equal "/courses/thales/fiche", Rails.application.routes.url_helpers.course_sheet_path("thales")
  end

  test "la route de la leçon et celle de ses fiches essentielles ne changent pas" do
    assert_equal({ controller: "catalog/courses", action: "show", slug: "thales" }, first_match("/courses/thales"))
    assert_equal({ controller: "catalog/essentials", action: "show", course_slug: "thales", slug: "mitose" },
                 first_match("/courses/thales/essentials/mitose"))
  end

  test "la fiche est en lecture seule" do
    %w[POST PATCH PUT DELETE].each { assert_nil first_match("/courses/thales/fiche", method: it), it }
  end
end
