# 🧠 DOMAINE · Policies::Billing::ActivateCardPolicy
# Rôle : activer une carte et lire Mon abonnement : l'élève seul
# ADR  : 0126 (contexte billing, PRD §2)
module Policies
  module Billing
    class ActivateCardPolicy
      def call(actor:)
        return Shared::Result.success if actor&.student?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
