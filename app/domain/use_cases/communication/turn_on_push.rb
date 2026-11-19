# 🧠 DOMAINE · UseCases::Communication::TurnOnPush
# Rôle : l'élève réactive les notifications : l'interrupteur « coupé » est effacé (le navigateur se réabonne ensuite)
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2)
module UseCases
  module Communication
    class TurnOnPush
      def initialize(users:, preferences:, policy:)
        @users = users
        @preferences = preferences
        @policy = policy
      end

      # → success | :forbidden
      def call(actor:)
        allowed = @policy.call(actor:, user: @users.find(id: actor&.user_id))
        return allowed if allowed.failure?

        @preferences.turn_on(user_id: actor.user_id)
        Shared::Result.success
      end
    end
  end
end
