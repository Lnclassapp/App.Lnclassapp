# 🧠 DOMAINE · UseCases::Communication::PostponePushInvitation
# Rôle : « Plus tard » sur la carte d'invitation : elle ne revient pas avant 7 jours (date gardée côté serveur)
# ADR  : 0146 (§4.2)
module UseCases
  module Communication
    class PostponePushInvitation
      DELAY = 7.days

      def initialize(users:, preferences:, policy:, clock:)
        @users = users
        @preferences = preferences
        @policy = policy
        @clock = clock
      end

      # → success | :forbidden
      def call(actor:)
        allowed = @policy.call(actor:, user: @users.find(id: actor&.user_id))
        return allowed if allowed.failure?

        @preferences.postpone_invitation(user_id: actor.user_id, until_time: @clock.now + DELAY)
        Shared::Result.success
      end
    end
  end
end
