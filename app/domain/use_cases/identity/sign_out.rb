# 🧠 DOMAINE · UseCases::Identity::SignOut
# Rôle : détruit la session serveur d'un jeton ; idempotent
# ADR  : 0050
module UseCases
  module Identity
    class SignOut
      def initialize(sessions:, digest_key:)
        @sessions = sessions
        @digest_key = digest_key
      end

      def call(token:)
        return Shared::Result.success if token.blank?

        session = @sessions.find_by_token_digest(token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key))
        @sessions.destroy(id: session.id) if session
        Shared::Result.success
      end
    end
  end
end
