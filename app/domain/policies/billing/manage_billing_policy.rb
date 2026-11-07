# 🧠 DOMAINE · Policies::Billing::ManageBillingPolicy
# Rôle : gérer points relais, lots, annulations, versements et caisse : l'équipe, quel que soit son sous-rôle
# ADR  : cartes-activation (contexte billing, PRD §2)
module Policies
  module Billing
    class ManageBillingPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
