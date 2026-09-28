# 🧠 DOMAINE · UseCases::Identity::ResolveSession
# Rôle : retrouve la session d'un jeton, l'expire ou la rafraîchit, et construit l'acteur
# ADR  : 0028, 0031, 0050, 0066
module UseCases
  module Identity
    class ResolveSession
      # actor est nil pour un compte de l'équipe ou de la direction dont le second facteur n'est pas vérifié (ADR-0031, ADR-0066).
      Resolved = Data.define(:actor, :session)

      def initialize(sessions:, users:, policy:, digest_key:, clock:)
        @sessions = sessions
        @users = users
        @policy = policy
        @digest_key = digest_key
        @clock = clock
      end

      # → success(Resolved) | :forbidden (aucune session) | :expired (la ligne est détruite)
      def call(token:)
        session = find(token)
        allowed = @policy.call(actor: nil, session:)
        return allowed if allowed.failure?

        now = @clock.now
        return expire(session) if Entities::Identity::SessionLifetime.expired?(
          role: session.role, created_at: session.created_at, last_seen_at: session.last_seen_at, now:
        )

        @sessions.touch(id: session.id, at: now) if Entities::Identity::SessionLifetime.touch_due?(last_seen_at: session.last_seen_at, now:)
        Shared::Result.success(Resolved.new(actor: actor_for(session), session:))
      end

      private

      def find(token)
        return if token.to_s.empty?

        @sessions.find_by_token_digest(token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key))
      end

      def expire(session)
        @sessions.destroy(id: session.id)
        Shared::Result.failure(:expired)
      end

      def actor_for(session)
        return if session.privileged? && !session.verified?

        @users.actor_for(user_id: session.user_id)
      end
    end
  end
end
