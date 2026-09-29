require "test_helper"

# ADR-0031 (amendement 2026-09-29): the screens that show a one-time secret are listed here, and each one is
# marked with `secret_response`. A new secret screen that forgets the mark, or a mark on a screen not listed,
# turns this test red.
class SecretResponseTest < ActionDispatch::IntegrationTest
  SECRET_ACTIONS = {
    "Identity::SecondFactorEnrollmentsController" => %w[create new], # clé TOTP, QR code, codes de secours
    "Identity::PinRecoveryCodesController" => %w[create],            # code de récupération du PIN
    "Teams::InvitationsController" => %w[create],                    # lien d'invitation de l'équipe
    "Teams::StaffInvitationsController" => %w[create]                # lien d'invitation de la direction
  }.freeze

  test "the one-time secret screens, and only they, are marked secret" do
    Rails.application.eager_load!

    marked = ApplicationController.descendants.filter_map do |controller|
      [ controller.name, controller.secret_actions.sort ] if controller.secret_actions.any?
    end

    assert_equal SECRET_ACTIONS, marked.to_h
  end

  test "a page without a secret keeps the default cache headers and the Turbo cache" do
    get new_session_path

    assert_response :success
    assert_equal "max-age=0, private, must-revalidate", response.headers["Cache-Control"]
    assert_not_secret_response
  end
end
