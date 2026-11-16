# 🧠 DOMAINE · UseCases::Communication::UnregisterPushSubscription
# Rôle : l'élève supprime un de ses abonnements Web Push ; l'abonnement d'un autre compte reste introuvable
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2, §4.3)
module UseCases
  module Communication
    class UnregisterPushSubscription
      def initialize(users:, subscriptions:, policy:)
        @users = users
        @subscriptions = subscriptions
        @policy = policy
      end

      # → success | :forbidden | :not_found
      def call(actor:, id:)
        allowed = @policy.call(actor:, user: @users.find(id: actor&.user_id))
        return allowed if allowed.failure?
        return Shared::Result.failure(:not_found) unless @subscriptions.for_user(user_id: actor.user_id).any? { it.id == id }

        @subscriptions.delete(id:)
        Shared::Result.success
      end
    end
  end
end
