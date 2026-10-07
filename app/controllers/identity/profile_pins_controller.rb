# 🌐 DELIVERY · Identity::ProfilePinsController
# Rôle : changer son PIN en modale, sous PIN actuel ; succès : nouvelle session, 303 vers « Mon profil » ; verrouillage : connexion
# ADR  : 0025, 0049, 0050, 0055 · UDR : 0006, 0041 (élève tutoyé, 2026-10-06)
module Identity
  class ProfilePinsController < AuthenticatedController
    include Tone

    def edit
      @form = Dtos::Identity::PinChangeInput.new
    end

    def update
      @form = form_input
      result = change.call(actor: current_actor, user: own_user, session: current_session, dto: @form)
      return locked_out(result.errors[:retry_after]) if result.code == :locked

      render_result result, form: :edit, success: lambda { |changed|
        start_session(changed.token)
        redirect_to main_app.profile_path, notice: tone_t(".changed"), status: :see_other
      }
    end

    private

    # Le compte vient d'être verrouillé par ces échecs : la session en cours se ferme, comme après la connexion (PR-07).
    def locked_out(retry_after)
      terminate_session
      redirect_to main_app.new_session_path, alert: locked_message(retry_after), status: :see_other
    end

    def form_input
      Dtos::Identity::PinChangeInput.new(
        **params.expect(pin_change: %i[current_pin pin pin_confirmation]).to_h.symbolize_keys,
        ip: request.remote_ip, user_agent: request.user_agent
      )
    end

    def own_user = users.find(id: current_actor.user_id)
    def users = @users ||= Repositories::Identity::UserRepository.new

    def change
      UseCases::Identity::ChangeOwnPin.new(
        users:, sessions: Repositories::Identity::SessionRepository.new, login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: Policies::Identity::UpdateSelfPolicy.new, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
