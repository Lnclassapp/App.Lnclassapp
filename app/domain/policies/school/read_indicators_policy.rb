# 🧠 DOMAINE · Policies::School::ReadIndicatorsPolicy
# Rôle : lire les indicateurs agrégés du pilotage : tout membre de l'équipe, quel que soit son sous-rôle
# ADR  : 0028, 0038, 0062
module Policies
  module School
    class ReadIndicatorsPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
