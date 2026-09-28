# 🧠 DOMAINE · Policies::Identity::ReadGrowthPolicy
# Rôle : seuls les membres de l'équipe lisent les indicateurs de croissance et le classement des établissements (V1)
# ADR  : 0028, 0063
module Policies
  module Identity
    class ReadGrowthPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
