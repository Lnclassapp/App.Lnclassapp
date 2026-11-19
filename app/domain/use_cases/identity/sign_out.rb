# 🧠 DOMAINE · UseCases::Identity::SignOut
# Rôle : détruit la session serveur d'un jeton ; idempotent
# ADR  : 0028, 0050, XXXX-notifications-web-push-aux-eleves
module UseCases
  module Identity
    class SignOut
      def initialize(sessions:, push_subscriptions:, policy:, digest_key:)
        @sessions = sessions
        @push_subscriptions = push_subscriptions
        @policy = policy
        @digest_key = digest_key
      end

      # → success, même quand la session n'existe plus
      def call(token:)
        session = @sessions.find_by_token_digest(token_digest: Entities::Identity::SecretDigest.hmac(token.to_s, key: @digest_key))
        close(session) if @policy.call(actor: nil, session:).success?
        Shared::Result.success
      end

      private

      # L'abonnement de l'appareil part avec sa session : ADR-XXXX §4.3 (une session expirée le garde, la clé est en SET NULL).
      def close(session)
        @push_subscriptions.delete_for_sessions(session_ids: [ session.id ])
        @sessions.destroy(id: session.id)
      end
    end
  end
end
