# 🧠 DOMAINE · Ports::Communication::PushApprovalRepositoryPort
# Rôle : contrat des validations passées (lues par l'historique, purgées à 90 jours) ; plus aucune n'est écrite depuis le 2026-11-27
# ADR  : 0147 (§4.2, amendement du 2026-11-27 II)
module Ports
  module Communication
    module PushApprovalRepositoryPort
      # → [Entities::Communication::PushApproval] depuis `since` (heure de validation), la plus récente d'abord
      def history(since:)
        raise NotImplementedError, "#{self.class} doit implémenter #history"
      end

      # Supprime les validations validées avant `before`, avec leurs destinataires → nombre supprimé
      def purge_before(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_before"
      end
    end
  end
end
