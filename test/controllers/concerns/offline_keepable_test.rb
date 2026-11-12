require "test_helper"

# hors-connexion, Lot 0 (ADR §4.1, menace P6) : l'en-tête « gardable » ne se pose que sur un 200 HTML d'un compte connecté.
class OfflineKeepableTest < ActiveSupport::TestCase
  Response = Struct.new(:status, :media_type, :headers) do
    def set_header(name, value) = headers[name] = value
  end

  class Host
    include OfflineKeepable

    attr_reader :response

    def initialize(connected:, response:, secret: false)
      @connected = connected
      @response = response
      @secret = secret
    end

    def authenticated? = @connected
    def secret_response? = @secret
    def mark = mark_offline_keepable
  end

  def headers_after(connected: true, status: 200, media_type: "text/html", secret: false, headers: {})
    response = Response.new(status, media_type, headers.dup)
    Host.new(connected:, response:, secret:).mark
    response.headers.except(*headers.keys)
  end

  test "un 200 HTML d'un compte connecté est marqué gardable" do
    assert_equal({ "Lnclass-Offline" => "keep" }, headers_after)
  end

  test "sans connexion, hors 200 ou hors HTML : rien" do
    assert_empty headers_after(connected: false)
    assert_empty headers_after(status: 302)
    assert_empty headers_after(media_type: "application/json")
  end

  test "une action secret_response ou une réponse no-store n'est jamais marquée (menace P6, revue sécurité du Lot 0)" do
    assert_empty headers_after(secret: true)
    assert_empty headers_after(headers: { "Cache-Control" => "private, no-store" })
  end

  test "keep_offline pose le rappel sur les actions demandées" do
    controller = Class.new(ApplicationController) { keep_offline only: :show }

    assert_includes controller._process_action_callbacks.map(&:filter), :mark_offline_keepable
  end
end
