require "test_helper"

# UDR-0006: the connected area renders the shell, except for a Turbo frame request, which keeps turbo-rails'
# minimal frame layout, so a modal or its 422 re-render lands in the frame that asked for it.
class AuthenticatedControllerTest < ActionDispatch::IntegrationTest
  class ProbeController < AuthenticatedController
    def show
      render html: helpers.turbo_frame_tag("modal") { "Formulaire" }, layout: true, status: :unprocessable_entity
    end
  end

  test "a normal request receives the shell" do
    sign_in_as create_student

    get pending_account_path

    assert_select "main#main"
  end

  test "a frame request receives the frame layout, without the shell" do
    sign_in_as create_student

    get pending_account_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "main#main", 0
    assert_select "#toasts", 0
  end

  # ADR-0049, ADR-0055: a session renewed from a modal (number or PIN changed) lands on a page asked for by the frame;
  # the shell carries the reload tag, so Turbo leaves the frame and reloads the whole document with the new nonce.
  test "the first Turbo frame request of a new session receives the shell, with the reload tag" do
    sign_in_as create_student

    get pending_account_path, headers: { "Turbo-Frame" => "modal", "X-Turbo-Request-Id" => "1" }

    assert_select "main#main"
    assert_select "meta[name=turbo-visit-control][content=reload]"
    get pending_account_path, headers: { "Turbo-Frame" => "modal", "X-Turbo-Request-Id" => "2" }
    assert_select "main#main", 0
  end

  test "a 422 re-render in a frame holds a single modal frame, with its content" do
    token = SecureRandom.base58(32)
    create_login_session(user: create_student, token:)

    with_routing do |set|
      set.draw { get "probe", to: "authenticated_controller_test/probe#show" }
      cookies[:session_token] = signed_cookie(token)
      get "/probe", headers: { "Turbo-Frame" => "modal" }

      assert_response :unprocessable_entity
      assert_select "turbo-frame#modal", count: 1, text: "Formulaire"
      assert_select "main#main", 0
    end
  end

  private

  # with_routing opens a new integration session: the cookie is set by hand, signed like the application signs it.
  def signed_cookie(token)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_token] = token
    jar[:session_token]
  end
end
