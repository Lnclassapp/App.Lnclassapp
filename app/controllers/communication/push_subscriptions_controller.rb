# 🌐 DELIVERY · Communication::PushSubscriptionsController
# Rôle : le navigateur de l'élève envoie (create) ou retire (destroy) son abonnement Web Push, en JSON ; l'abonnement est rattaché à la session courante
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2, §4.3) · UDR : XXXX-notifications-eleve (§3.1) · jamais d'identifiant d'élève lu des paramètres
module Communication
  class PushSubscriptionsController < AuthenticatedController
    allow_roles :student

    def create
      result = register.call(actor: current_actor, session_id: current_session.id, endpoint: string_param(:endpoint),
                             p256dh: string_param(:keys, :p256dh), auth: string_param(:keys, :auth))
      return render json: { errors: result.errors }, status: :unprocessable_entity if result.code == :invalid

      render_result result, success: ->(subscription) { render json: { id: subscription.id }, status: :created }
    end

    def destroy
      render_result unregister.call(actor: current_actor, id: params[:id].to_i), success: ->(_) { head :no_content }
    end

    private

    # Seule une chaîne est lue : un tableau ou un objet forgé devient nil, et le use case le refuse.
    def string_param(*keys)
      value = nested_param(*keys)
      value if value.is_a?(String)
    end

    def dependencies
      { users: Repositories::Identity::UserRepository.new, subscriptions: Repositories::Communication::PushSubscriptionRepository.new,
        policy: Policies::Communication::PushSubscriptionPolicy.new }
    end

    def register = UseCases::Communication::RegisterPushSubscription.new(**dependencies)
    def unregister = UseCases::Communication::UnregisterPushSubscription.new(**dependencies)
  end
end
