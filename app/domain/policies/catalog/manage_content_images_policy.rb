# 🧠 DOMAINE · Policies::Catalog::ManageContentImagesPolicy
# Rôle : envoyer, remplacer, retirer une image de cours, ou lire une image pas encore rattachée : l'équipe `admin` et `content` seules
# ADR  : 0028, 0038, 0089
module Policies
  module Catalog
    # Plus étroite que ManageContentPolicy (toute l'équipe) : le rôle terrain ne touche pas aux images (PRD §2, grill question 11).
    class ManageContentImagesPolicy
      TEAM_ROLES = %w[admin content].freeze

      def call(actor:)
        return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
