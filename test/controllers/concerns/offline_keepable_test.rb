require "test_helper"

# hors-connexion, Lot 0 (ADR §4.1, menace P6) : l'en-tête « gardable » ne se pose que sur un 200 HTML d'un compte connecté.
class OfflineKeepableTest < ActiveSupport::TestCase
  Response = Struct.new(:status, :media_type, :headers) do
    def set_header(name, value) = headers[name] = value
  end

  class Host
    include OfflineKeepable

    attr_reader :response

    def initialize(connected:, response:)
      @connected = connected
      @response = response
    end

    def authenticated? = @connected
    def mark = mark_offline_keepable
  end

  def headers_after(connected: true, status: 200, media_type: "text/html")
    response = Response.new(status, media_type, {})
    Host.new(connected:, response:).mark
    response.headers
  end

  test "un 200 HTML d'un compte connecté est marqué gardable" do
    assert_equal({ "Lnclass-Offline" => "keep" }, headers_after)
  end

  test "sans connexion, hors 200 ou hors HTML : rien" do
    assert_empty headers_after(connected: false)
    assert_empty headers_after(status: 302)
    assert_empty headers_after(media_type: "application/json")
  end

  test "keep_offline pose le rappel sur les actions demandées" do
    controller = Class.new(ApplicationController) { keep_offline only: :show }

    assert_includes controller._process_action_callbacks.map(&:filter), :mark_offline_keepable
  end
end
