# 🌐 DELIVERY · Identity::SecondFactorsController
# Rôle : vérification du second facteur de l'équipe et de la direction (code TOTP ou de secours), une fois par session
# ADR  : 0026, 0031, 0050, 0066 · UDR : 0052
module Identity
  class SecondFactorsController < ApplicationController
    allow_unverified_second_factor
    before_action :leave_when_not_expected
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited(:new) }

    def new
      @form = Dtos::Identity::SecondFactorCodeInput.new
    end

    def create
      @form = form_input
      render_result verify.call(session: current_session, dto: @form, ip: request.remote_ip), form: :new, success: lambda { |_|
        forget_resolution
        redirect_to_home notice: t(".verified"), status: :see_other
      }
    end

    private

    # Déjà vérifié (ou compte sans second facteur) : l'accueil ; pas encore enrôlé : l'enrôlement.
    def leave_when_not_expected
      return redirect_to_home if current_actor

      redirect_to main_app.new_identity_second_factor_enrollment_path unless current_session.second_factor_confirmed
    end

    def form_input = Dtos::Identity::SecondFactorCodeInput.new(code: params.dig(:second_factor, :code))

    def verify
      UseCases::Identity::VerifySecondFactor.new(
        users: Repositories::Identity::UserRepository.new, second_factors: Repositories::Identity::SecondFactorRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::Identity::SecondFactorPolicy.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
