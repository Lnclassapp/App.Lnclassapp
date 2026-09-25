# 🧠 DOMAINE · UseCases::Identity::SignOut
# Rôle : détruit la session serveur d'un jeton ; idempotent
# ADR  : 0028, 0050
module UseCases
  module Identity
    class SignOut
      def initialize(sessions:, policy:, digest_key:)
        @sessions = sessions
        @policy = policy
        @digest_key = digest_key
      end

      # → success, même quand la session n'existe plus
      def call(token:)
        session = @sessions.find_by_token_digest(token_digest: Entities::Identity::SecretDigest.hmac(token.to_s, key: @digest_key))
        @sessions.destroy(id: session.id) if @policy.call(actor: nil, session:).success?
        Shared::Result.success
      end
    end
  end
end
