# 🧠 DOMAINE · Policies::Identity::EraseAuditIpsPolicy
# Rôle : seul le système (tâche planifiée, acteur nil) efface les IP du journal d'audit ; toute personne est refusée
# ADR  : 0028, 0080
module Policies
  module Identity
    class EraseAuditIpsPolicy
      def call(actor:)
        return Shared::Result.success if actor.nil?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
