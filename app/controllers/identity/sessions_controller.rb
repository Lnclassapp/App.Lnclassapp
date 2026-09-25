# 🌐 DELIVERY · Identity::SessionsController
# Rôle : connexion par numéro et PIN, déconnexion ; échec re-rendu en 422 (le champ PIN ne renvoie jamais sa valeur)
# ADR  : 0026, 0050
module Identity
  class SessionsController < ApplicationController
    allow_unauthenticated_access only: %i[new create]
    allow_unverified_second_factor only: :destroy
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited(:new) }

    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::CredentialsInput.new
    end

    def create
      @form = form_input
      render_result authenticate.call(dto: @form), form: :new, success: lambda { |authenticated|
        start_session(authenticated.token)
        redirect_to_home notice: t(".signed_in"), status: :see_other
      }
    end

    def destroy
      terminate_session
      redirect_to main_app.root_path, notice: t(".signed_out"), status: :see_other
    end

    private

    def form_input
      Dtos::Identity::CredentialsInput.new(
        **params.expect(session: %i[contact pin]).to_h.symbolize_keys, ip: request.remote_ip, user_agent: request.user_agent
      )
    end

    def authenticate
      UseCases::Identity::Authenticate.new(
        users: Repositories::Identity::UserRepository.new, login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
