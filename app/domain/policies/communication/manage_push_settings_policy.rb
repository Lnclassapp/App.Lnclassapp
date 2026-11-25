# 🧠 DOMAINE · Policies::Communication::ManagePushSettingsPolicy
# Rôle : changer la case « Automatique » d'un motif de notification : l'équipe, rôle `admin` seul
# ADR  : 0028 · XXXX envois de notifications (§4.1) · UDR : XXXX écran notifications de l'équipe (§3.3)
module Policies
  module Communication
    class ManagePushSettingsPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team? && actor.team_role == "admin"

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
