# 🧠 DOMAINE · Policies::Communication::ApprovePushPolicy
# Rôle : valider l'envoi d'un motif dans le plan du jour : toute l'équipe, quel que soit son rôle d'équipe
# ADR  : XXXX envois de notifications (§4.4) · UDR : XXXX écran notifications de l'équipe (§3.4)
module Policies
  module Communication
    class ApprovePushPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
