# 🧠 DOMAINE · UseCases::Identity::SessionRenewal
# Rôle : après un changement de numéro ou de PIN, une nouvelle session remplace toutes les autres, celle en cours comprise
# ADR  : 0049, 0055
module UseCases
  module Identity
    # Partagé par ChangeOwnContact et ChangeOwnPin, qui fournissent @sessions et @digest_key. Le second facteur vérifié
    # le reste. Rend le jeton en clair de la nouvelle session, que le contrôleur pose dans le cookie (start_session).
    module SessionRenewal
      private

      def renew(user, session, dto, now)
        token = Entities::Identity::SecretDigest.generate_token
        id = @sessions.create(user_id: user.id, token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                              ip: dto.ip, user_agent: dto.user_agent, at: now)
        @sessions.mark_second_factor_verified(id:, at: now) if session.verified?
        @sessions.destroy_all_except(user_id: user.id, keep_id: id)
        token
      end
    end
  end
end
