# 🧠 DOMAINE · UseCases::Identity::ResolveSession
# Rôle : retrouve la session d'un jeton, l'expire ou la rafraîchit, et construit l'acteur
# ADR  : 0028, 0031, 0050
module UseCases
  module Identity
    class ResolveSession
      # actor est nil pour un compte team dont le second facteur n'est pas vérifié.
      Resolved = Data.define(:actor, :user_id, :role, :session_id, :second_factor_verified)

      def initialize(sessions:, users:, digest_key:, clock:)
        @sessions = sessions
        @users = users
        @digest_key = digest_key
        @clock = clock
      end

      def call(token:)
        return Shared::Result.failure(:expired) if token.blank?

        session = @sessions.find_by_token_digest(token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key))
        return Shared::Result.failure(:expired) unless session

        now = @clock.now
        if Entities::Identity::SessionLifetime.expired?(role: session.role, created_at: session.created_at,
                                                         last_seen_at: session.last_seen_at, now:)
          @sessions.destroy(id: session.id)
          return Shared::Result.failure(:expired)
        end

        @sessions.touch(id: session.id, at: now) if Entities::Identity::SessionLifetime.touch_due?(last_seen_at: session.last_seen_at, now:)
        Shared::Result.success(resolved(session))
      end

      private

      def resolved(session)
        verified = !session.second_factor_verified_at.nil?
        actor = @users.actor_for(user_id: session.user_id) unless session.role.to_s == "team" && !verified
        Resolved.new(actor:, user_id: session.user_id, role: session.role.to_sym, session_id: session.id,
                     second_factor_verified: verified)
      end
    end
  end
end
