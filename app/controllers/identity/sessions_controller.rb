# 🌐 DELIVERY · Identity::SessionsController
# Rôle : connexion par numéro et PIN, déconnexion ; échec re-rendu en 422 (le champ PIN ne renvoie jamais sa valeur)
# ADR  : 0026, 0050 · UDR : 0019, 0054 (§3.8 : numéro pré-rempli après une invitation, à usage unique)
module Identity
  class SessionsController < ApplicationController
    allow_unauthenticated_access only: %i[new create]
    allow_unverified_second_factor only: :destroy
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited(:new) }

    # Le numéro laissé par une invitation acceptée est lu et supprimé : un rechargement ne le montre plus.
    def new
      contact = Entities::Identity::Contact.normalize(session.delete(:login_contact))
      return redirect_to_home if authenticated?

      @prefilled = contact.present?
      @form = Dtos::Identity::CredentialsInput.new
      @form.contact = contact.scan(/\d{2}/).join(" ") if @prefilled
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
