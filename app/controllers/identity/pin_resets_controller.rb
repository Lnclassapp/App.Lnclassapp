# 🌐 DELIVERY · Identity::PinResetsController
# Rôle : nouveau PIN par le code de récupération à 8 chiffres remis par l'enseignant ou l'équipe
# ADR  : 0026, 0032, 0050
module Identity
  class PinResetsController < ApplicationController
    allow_unauthenticated_access
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited(:new) }

    def new
      @form = Dtos::Identity::PinResetInput.new
    end

    def create
      @form = form_input
      render_result reset.call(dto: @form), form: :new, success: lambda { |_|
        redirect_to main_app.new_session_path, notice: t(".pin_changed"), status: :see_other
      }
    end

    private

    def form_input
      Dtos::Identity::PinResetInput.new(
        **params.expect(pin_reset: %i[contact code pin pin_confirmation]).to_h.symbolize_keys, ip: request.remote_ip
      )
    end

    def reset
      UseCases::Identity::ResetPinWithCode.new(
        users: Repositories::Identity::UserRepository.new, pin_recoveries: Repositories::Identity::PinRecoveryRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
