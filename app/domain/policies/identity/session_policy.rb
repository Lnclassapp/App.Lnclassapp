# 🧠 DOMAINE · Policies::Identity::SessionPolicy
# Rôle : le porteur d'un jeton n'agit que sur sa propre session (résoudre, se déconnecter)
# ADR  : 0028, 0031, 0050
module Policies
  module Identity
    class SessionPolicy
      # session : Entities::Identity::SessionState trouvée par l'empreinte du jeton, ou nil ;
      # actor : nil tant que la session n'est pas résolue
      def call(actor:, session:)
        return Shared::Result.failure(:forbidden) if session.nil?
        return Shared::Result.failure(:forbidden) if actor && actor.user_id != session.user_id

        Shared::Result.success
      end
    end
  end
end
