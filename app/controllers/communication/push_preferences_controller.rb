# 🌐 DELIVERY · Communication::PushPreferencesController
# Rôle : PATCH /push_preference, `intent` = turn_off | turn_on | postpone : « Couper », « Réactiver » (ligne du profil) et « Plus tard » (carte d'invitation)
# ADR  : 0146 (§4.2) · UDR : 0186 (§3.1, §3.2) · Turbo Stream, repli HTML par redirection, JSON sans corps
module Communication
  class PushPreferencesController < AuthenticatedController
    allow_roles :student

    INTENTS = %w[turn_off turn_on postpone].freeze

    def update
      intent = params[:intent]
      return head :unprocessable_entity unless INTENTS.include?(intent)

      render_result run(intent), success: ->(_) { answer(intent) }
    end

    private

    def run(intent)
      case intent
      when "turn_off" then turn_off.call(actor: current_actor, session_id: current_session.id)
      when "turn_on" then turn_on.call(actor: current_actor)
      else postpone.call(actor: current_actor)
      end
    end

    def answer(intent)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: stream(intent) }
        format.json { head :no_content }
        format.html { redirect_after(intent) }
      end
    end

    # « Plus tard » retire la carte ; « Couper » et « Réactiver » remplacent la ligne du profil (état dit par l'action, pas relu).
    def stream(intent)
      return turbo_stream.remove("push_invitation") if intent == "postpone"

      turbo_stream.replace("profile_notifications_row", partial: "identity/profiles/push_row", locals: { state: (intent == "turn_off" ? :off : :on) })
    end

    def redirect_after(intent)
      return redirect_back_or_to(student_home_path, status: :see_other) if intent == "postpone"

      redirect_to profile_path, status: :see_other, notice: t(".#{intent}")
    end

    def dependencies
      { users: Repositories::Identity::UserRepository.new, preferences: Repositories::Communication::PushPreferenceRepository.new,
        policy: Policies::Communication::PushSubscriptionPolicy.new }
    end

    def turn_off
      UseCases::Communication::TurnOffPush.new(**dependencies, subscriptions: Repositories::Communication::PushSubscriptionRepository.new,
                                                              clock: Time.zone)
    end

    def turn_on = UseCases::Communication::TurnOnPush.new(**dependencies)
    def postpone = UseCases::Communication::PostponePushInvitation.new(**dependencies, clock: Time.zone)
  end
end
