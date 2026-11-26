# 🧠 DOMAINE · Ports::Communication::PushApprovalRepositoryPort
# Rôle : contrat des validations du jour par l'équipe et de leurs destinataires figés (gelé par le Lot 0)
# ADR  : XXXX envois de notifications (§4.2)
module Ports
  module Communication
    module PushApprovalRepositoryPort
      # → Set<[user_id, motive, object_key]> : ce que les validations du jour d'Abidjan ont figé
      def approved_keys(on_date:)
        raise NotImplementedError, "#{self.class} doit implémenter #approved_keys"
      end

      # → [Entities::Communication::PushApproval] : les validations de ce jour
      def for_date(on_date:)
        raise NotImplementedError, "#{self.class} doit implémenter #for_date"
      end

      # `recipients` : [[user_id, object_key], …]. Unique par (on_date, motive) : la seconde validation répond :already_approved.
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
