require "test_helper"

# ADR-0026: one translation from a use case result to an HTTP response, for every controller.
class RendersResultTest < ActionDispatch::IntegrationTest
  FORM = "identity/second_factors/new".freeze
  RESULTS = {
    "success" => Shared::Result.success("done"),
    "forbidden" => Shared::Result.failure(:forbidden),
    "not_found" => Shared::Result.failure(:not_found),
    "invalid" => Shared::Result.failure(:invalid, errors: { code: [ :invalid ] }),
    "invalid_bare" => Shared::Result.failure(:invalid),
    "conflict" => Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] }),
    "locked" => Shared::Result.failure(:locked, errors: { retry_after: 15.minutes }),
    "locked_until_recovery" => Shared::Result.failure(:locked, errors: { retry_after: :until_recovery }),
    "expired" => Shared::Result.failure(:expired)
  }.freeze

  class ProbeController < ApplicationController
    allow_unauthenticated_access

    def show
      @form = Dtos::Identity::SecondFactorCodeInput.new
      @form.errors.add(:code, :invalid) if params[:preset]
      render_result RESULTS.fetch(params[:case]), form: (FORM if params[:form]), success: ->(value) { render plain: value }
    end
  end

  with_routing do |set|
    set.draw do
      root to: "homepage#index"
      get "login", to: "identity/sessions#new", as: :new_session
      resource :session, only: :destroy, controller: "identity/sessions"
      namespace(:identity) { resource :second_factor, only: %i[new create], path: "second-factor" }
      get "probe", to: "renders_result_test/probe#show"
    end
  end

  test "a success hands the value to the controller" do
    probe "success"

    assert_response :ok
    assert_equal "done", response.body
  end

  test "forbidden renders the 403 page, JSON or a toast" do
    probe "forbidden"

    assert_response :forbidden
    assert_select "p", text: "Accès interdit."

    probe "forbidden", format: :json

    assert_response :forbidden
    assert_equal({ "error" => "forbidden" }, response.parsed_body)

    probe "forbidden", headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :forbidden
    assert_match(/turbo-stream action="append" target="toasts"/, response.body)
  end

  test "not found renders the 404 page" do
    probe "not_found"

    assert_response :not_found
    assert_select "p", text: "Page introuvable."
  end

  test "invalid renders the form in 422 with the errors of the use case" do
    probe "invalid", form: true

    assert_response :unprocessable_entity
    assert_select "#second_factor_code_error", text: "Code incorrect."
  end

  test "an error already carried by the form is not repeated" do
    probe "invalid", form: true, preset: true

    assert_select "#second_factor_code_error", count: 1
  end

  test "a failure without named errors receives the message of its code" do
    probe "invalid_bare", form: true

    assert_select "[role=alert]", text: "Vérifiez les informations saisies."
  end

  test "conflict renders the form in 422" do
    probe "conflict", form: true

    assert_response :unprocessable_entity
  end

  test "locked renders the form in 429 with the unlock time" do
    freeze_time do
      probe "locked", form: true

      assert_response :too_many_requests
      assert_select "[role=alert]", text: "Trop de tentatives. Réessayez à #{I18n.l(15.minutes.from_now, format: :hour_minute)}."
    end
  end

  test "locked until recovery says so" do
    probe "locked_until_recovery", form: true

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /code de récupération/
  end

  test "expired renders the form when there is one, the sign-in page otherwise" do
    probe "expired", form: true

    assert_response :unprocessable_entity

    probe "expired"

    assert_redirected_to "/login"
    assert_equal "Votre connexion a expiré. Connectez-vous de nouveau.", flash[:alert]
  end

  private

  def probe(kase, format: nil, headers: {}, **params)
    get "/probe", params: { case: kase, format:, **params }.compact, headers:
  end
end
