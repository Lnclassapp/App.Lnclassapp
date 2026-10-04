# 🧠 DOMAINE · Policies::Communication::WithdrawPolicy
# Rôle : l'équipe retire toute annonce d'un autre auteur, la direction celles des enseignants de son établissement ; figée, plus rien
# ADR  : 0028, 0078 (§4.2) · UDR : 0071 (§3.7)
module Policies
  module Communication
    class WithdrawPolicy
      # message : Entities::Communication::Message, ou nil (public_id inconnu) ; author_role : le rôle du compte auteur.
      # Hors droit, l'annonce n'existe pas pour l'acteur (not_found, ADR-0078 §4.2) ; le droit d'abord, puis l'état.
      def call(actor:, message:, author_role:)
        return Shared::Result.failure(:not_found) unless actor && message&.moderatable_by?(actor, author_role:)
        return Shared::Result.failure(:conflict) if message.frozen?

        Shared::Result.success
      end
    end
  end
end
