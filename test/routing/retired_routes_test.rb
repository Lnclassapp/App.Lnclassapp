require "test_helper"

# CA-17 (refonte-contenus-maths, Lot R) : les adresses d'images de notions sont retirées ; l'ancienne adresse de la fiche
# reste, servie par le contrôleur de la leçon.
class RetiredRoutesTest < ActionDispatch::IntegrationTest
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action, :course_slug) }
    nil
  end

  test "l'adresse d'une image de notion ne mène plus nulle part" do
    assert_nil first_match("/images/fiches/abc")
  end

  test "l'envoi d'une image de notion par l'équipe ne mène plus nulle part" do
    assert_nil first_match("/teams/essential-images", method: "POST")
  end

  test "l'envoi d'une image de question reste" do
    assert_equal "teams/question_images", first_match("/teams/question-images", method: "POST")[:controller]
  end

  test "courses/:course_slug/fiche est servie par le contrôleur de la leçon, en lecture seule" do
    assert_equal({ controller: "catalog/courses", action: "fiche", course_slug: "thales" }, first_match("/courses/thales/fiche"))
    %w[POST PATCH PUT DELETE].each { assert_nil first_match("/courses/thales/fiche", method: it), it }
  end
end
