require "test_helper"

# ADR-0081 §4.3, UDR-0075 §3.5 : les routes de la bibliothèque d'illustrations d'annonce, dessinées par le Lot 0 pour le
# Lot C, noms et chemins gelés. Une illustration se désigne par son public_id ; elle n'est jamais supprimée. Les routes
# sont reconnues sans charger leurs contrôleurs, que le Lot C apporte.
class AnnouncementIllustrationsRoutesTest < ActionDispatch::IntegrationTest
  PUBLIC_ID = "abcdefghijkmno".freeze
  PREFIX = "/teams/announcement-illustrations".freeze

  # verb, path, controller#action, named route (with its argument)
  ROUTES = [
    [ "GET", PREFIX, "teams/announcement_illustrations#index", [ :teams_announcement_illustrations_path ] ],
    [ "POST", PREFIX, "teams/announcement_illustrations#create", [ :teams_announcement_illustrations_path ] ],
    [ "GET", "#{PREFIX}/#{PUBLIC_ID}/edit", "teams/announcement_illustrations#edit",
      [ :edit_teams_announcement_illustration_path, PUBLIC_ID ] ],
    [ "PATCH", "#{PREFIX}/#{PUBLIC_ID}", "teams/announcement_illustrations#update", [ :teams_announcement_illustration_path, PUBLIC_ID ] ],
    [ "POST", "#{PREFIX}/#{PUBLIC_ID}/retirement", "teams/announcement_illustration_retirements#create",
      [ :teams_announcement_illustration_retirement_path, PUBLIC_ID ] ]
  ].freeze

  def helpers = Rails.application.routes.url_helpers

  def library_routes = Rails.application.routes.routes.select { it.path.spec.to_s.start_with?(PREFIX) }

  # The first matching route, without loading its controller (Rails 8 draws the routes lazily: `routes` draws them).
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action, :public_id) }
    nil
  end

  test "every named route builds its frozen path" do
    ROUTES.each do |_verb, path, _target, (name, *arguments)|
      assert_equal path, helpers.public_send(name, *arguments), name
    end
  end

  test "every verb and path reaches its controller and action, with the public_id" do
    ROUTES.each do |verb, path, target, (_name, public_id)|
      controller, action = target.split("#")

      assert_equal({ controller:, action:, public_id: }.compact, first_match(path, method: verb), "#{verb} #{path}")
    end
  end

  test "the routes are drawn in the frozen order, and nothing else lives under the library" do
    drawn = library_routes.map { [ it.verb, it.defaults.values_at(:controller, :action).join("#") ] }

    assert_equal ROUTES.map { [ it[0], it[2] ] }, drawn
  end

  test "AV-10 — no deletion, no page of detail, no PUT, no form outside the page, no numeric id" do
    assert_nil first_match("#{PREFIX}/#{PUBLIC_ID}", method: "DELETE")
    assert_nil first_match("#{PREFIX}/#{PUBLIC_ID}/retirement", method: "DELETE")
    assert_nil first_match("#{PREFIX}/#{PUBLIC_ID}")
    assert_nil first_match("#{PREFIX}/#{PUBLIC_ID}", method: "PUT")
    assert_nil first_match("#{PREFIX}/#{PUBLIC_ID}/retirement")
    assert_nil first_match("#{PREFIX}/new")
    library_routes.each do |route|
      assert_empty route.path.spec.to_s.scan(/:\w+/) - %w[:public_id :format], route.path.spec.to_s
    end
  end
end
