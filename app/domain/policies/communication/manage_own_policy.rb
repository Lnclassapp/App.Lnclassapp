# 🧠 DOMAINE · Policies::Communication::ManageOwnPolicy
# Rôle : seul son auteur modifie, programme ou archive une annonce ; pour tout autre, elle n'existe pas ; archivée ou retirée, elle est figée
# ADR  : 0028, 0078 · UDR : 0071
module Policies
  module Communication
    class ManageOwnPolicy
      # message : Entities::Communication::Message, ou nil (public_id inconnu). L'équipe et la direction comprises,
      # un autre que l'auteur reçoit not_found (ADR-0078 §4.2) ; retirer n'est pas modifier.
      def call(actor:, message:)
        return Shared::Result.failure(:not_found) unless actor && message && message.author_id == actor.user_id
        return Shared::Result.failure(:conflict) if message.frozen?

        Shared::Result.success
      end
    end
  end
end
