# 🌐 DELIVERY · Communication::PushSubscriptionsController
# Rôle : le navigateur de l'élève envoie (create) son abonnement Web Push, en JSON ; l'abonnement est rattaché à la session courante
# ADR  : 0146 (§4.2, §4.3) · UDR : 0186 (§3.1) · jamais d'identifiant d'élève lu des paramètres
module Communication
  class PushSubscriptionsController < AuthenticatedController
    allow_roles :student

    # Un navigateur s'abonne une fois : 10 enregistrements par minute et par élève suffisent (ADR §4.3, anti-abus).
    rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_actor.user_id }, with: -> { head :too_many_requests }

    def create
      result = register.call(actor: current_actor, session_id: current_session.id, endpoint: string_param(:endpoint),
                             p256dh: string_param(:keys, :p256dh), auth: string_param(:keys, :auth))
      return render json: { errors: result.errors }, status: :unprocessable_entity if result.code == :invalid

      render_result result, success: ->(subscription) { render json: { id: subscription.id }, status: :created }
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
  end
end
