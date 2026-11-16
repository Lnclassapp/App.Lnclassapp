# 🧠 DOMAINE · UseCases::Communication::TurnOffPush
# Rôle : l'élève coupe les notifications : l'interrupteur est posé pour tous ses navigateurs, l'abonnement de la session courante est supprimé
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2)
module UseCases
  module Communication
    class TurnOffPush
      def initialize(users:, preferences:, subscriptions:, policy:, clock:)
        @users = users
        @preferences = preferences
        @subscriptions = subscriptions
        @policy = policy
        @clock = clock
      end

      # → success | :forbidden
      def call(actor:, session_id:)
        allowed = @policy.call(actor:, user: @users.find(id: actor&.user_id))
        return allowed if allowed.failure?

        @preferences.turn_off(user_id: actor.user_id, at: @clock.now)
        @subscriptions.delete_for_sessions(session_ids: [ session_id ])
        Shared::Result.success
      end
    end
  end
end
