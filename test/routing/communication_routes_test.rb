require "test_helper"

# ADR-0078 §4.6 and §6, UDR-0071 §3.7: every route of the announcements, drawn by the Lot 0 for the lots A, B and C,
# names and paths frozen. A message is addressed by its public_id, never by an :id; there is no page of detail.
class CommunicationRoutesTest < ActionDispatch::IntegrationTest
  PUBLIC_ID = "abcdefghijkmno".freeze

  # verb, path, controller#action, named route (with its arguments)
  ROUTES = [
    [ "GET", "/announcements", "communication/inboxes#show", [ :announcements_path ] ],
    [ "GET", "/announcements/mine", "communication/authored_messages#index", [ :my_announcements_path ] ],
    [ "GET", "/announcements/moderation", "communication/moderations#index", [ :moderated_announcements_path ] ],
    [ "GET", "/announcements/new", "communication/authored_messages#new", [ :new_announcement_path ] ],
    [ "POST", "/announcements", "communication/authored_messages#create", [ :announcements_path ] ],
    [ "GET", "/announcements/#{PUBLIC_ID}/edit", "communication/authored_messages#edit", [ :edit_announcement_path, PUBLIC_ID ] ],
    [ "PATCH", "/announcements/#{PUBLIC_ID}", "communication/authored_messages#update", [ :announcement_path, PUBLIC_ID ] ],
    [ "POST", "/announcements/#{PUBLIC_ID}/archive", "communication/message_archives#create", [ :announcement_archive_path, PUBLIC_ID ] ],
    [ "POST", "/announcements/#{PUBLIC_ID}/withdrawal", "communication/message_withdrawals#create",
      [ :announcement_withdrawal_path, PUBLIC_ID ] ],
    [ "POST", "/announcements/#{PUBLIC_ID}/dismissal", "communication/message_dismissals#create",
      [ :announcement_dismissal_path, PUBLIC_ID ] ],
    [ "DELETE", "/announcements/#{PUBLIC_ID}/dismissal", "communication/message_dismissals#destroy",
      [ :announcement_dismissal_path, PUBLIC_ID ] ],
    [ "GET", "/announcements/#{PUBLIC_ID}/image", "communication/message_files#show", [ :announcement_file_path, PUBLIC_ID, { kind: "image" } ] ],
    [ "GET", "/announcements/#{PUBLIC_ID}/audio", "communication/message_files#show", [ :announcement_file_path, PUBLIC_ID, { kind: "audio" } ] ]
  ].freeze

  def helpers = Rails.application.routes.url_helpers

  def announcement_routes
    Rails.application.routes.routes.select { it.path.spec.to_s.start_with?("/announcements") }
  end

  # The first matching route, without loading its controller (the lots A, B and C bring them).
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action, :public_id, :kind) }
    nil
  end

  test "every named route builds its frozen path" do
    ROUTES.each do |_verb, path, _target, (name, *arguments)|
      positional = arguments.grep_v(Hash)
      assert_equal path, helpers.public_send(name, *positional, **arguments.grep(Hash).reduce({}, :merge)), name
    end
  end

  test "every verb and path reaches its controller and action, with the public_id and the kind of file" do
    ROUTES.each do |verb, path, target, (_name, public_id, kind)|
      controller, action = target.split("#")
      expected = { controller:, action:, public_id:, kind: kind&.fetch(:kind) }.compact

      assert_equal expected, first_match(path, method: verb), "#{verb} #{path}"
    end
  end

  test "the routes are drawn in the frozen order, and nothing else lives under /announcements" do
    drawn = announcement_routes.map { [ it.verb, it.defaults.values_at(:controller, :action).join("#") ] }

    assert_equal ROUTES.map { [ it[0], it[2] ] }.uniq, drawn
  end

  test "no page of detail, no PUT, no other kind of file, no numeric id" do
    assert_nil first_match("/announcements/#{PUBLIC_ID}")
    assert_nil first_match("/announcements/#{PUBLIC_ID}", method: "PUT")
    assert_nil first_match("/announcements/#{PUBLIC_ID}/video")
    assert_nil first_match("/announcements/#{PUBLIC_ID}/images")
    assert_nil first_match("/announcements/#{PUBLIC_ID}/archive")
    announcement_routes.each do |route|
      assert_empty route.path.spec.to_s.scan(/:\w+/) - %w[:public_id :kind :format], route.path.spec.to_s
    end
  end

  test "AN-23 — the routes that write an announcement live under /announcements, never under /school-admin" do
    writes = announcement_routes.reject { it.verb == "GET" }

    assert_equal 6, writes.size
    assert(writes.all? { it.path.spec.to_s.start_with?("/announcements") })
    # ADR-0078, amendment of 2026-10-04: since ADR-0071, /school-admin has writes of its own; none of them is an announcement.
    school_admin = Rails.application.routes.routes.select { it.path.spec.to_s.start_with?("/school-admin") }
    assert(school_admin.none? { it.defaults[:controller].to_s.start_with?("communication/") })
  end
end
