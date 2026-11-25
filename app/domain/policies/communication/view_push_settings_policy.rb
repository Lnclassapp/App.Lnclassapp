# 🧠 DOMAINE · Policies::Communication::ViewPushSettingsPolicy
# Rôle : voir la page « Notifications » (réglages, historique) : toute l'équipe, quel que soit son rôle d'équipe
# ADR  : 0028 · XXXX envois de notifications · UDR : XXXX écran notifications de l'équipe (§3.1)
module Policies
  module Communication
    class ViewPushSettingsPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
