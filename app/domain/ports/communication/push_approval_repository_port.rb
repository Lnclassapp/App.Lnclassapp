# 🧠 DOMAINE · Ports::Communication::PushApprovalRepositoryPort
# Rôle : contrat des validations du jour par l'équipe et des élèves concernés au moment de la validation
# ADR  : XXXX envois de notifications (§4.2)
module Ports
  module Communication
    module PushApprovalRepositoryPort
      # → [Entities::Communication::PushApproval] : les validations de ce jour ; chacune ouvre son motif jusqu'au soir
      def for_date(on_date:)
        raise NotImplementedError, "#{self.class} doit implémenter #for_date"
      end

      # `recipients` : [[user_id, object_key], …], les élèves concernés au moment de la validation (leur nombre est affiché). Unique par (on_date, motive) : la seconde validation répond :already_approved.
      # → :created | :already_approved
      def create(on_date:, motive:, by:, at:, recipients:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

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
