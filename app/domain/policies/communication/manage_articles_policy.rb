# 🧠 DOMAINE · Policies::Communication::ManageArticlesPolicy
# Rôle : gérer le blog : l'équipe `admin` et `content` seules (matrice de l'ADR-0038, ligne « Blog »)
# ADR  : 0028, 0038, 0073
module Policies
  module Communication
    class ManageArticlesPolicy
      TEAM_ROLES = %w[admin content].freeze

      def call(actor:)
        return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
