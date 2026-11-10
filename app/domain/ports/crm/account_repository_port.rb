# 🧠 DOMAINE · Ports::Crm::AccountRepositoryPort
# Rôle : contrat du suivi d'une école : étape saisie, responsable, motif de perte ; créé à la première écriture
# ADR  : XXXX (contexte crm) · gelé par le Lot 0
module Ports
  module Crm
    module AccountRepositoryPort
      # → Entities::Crm::Account | nil (aucune ligne = Prospect sans responsable)
      def find_by_school_id(school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_school_id"
      end

      # Crée ou met à jour la ligne de l'école. → Result(Account) | failure(:invalid, errors: { lost_reason: [:blank] }) si « perdue » sans motif
      def save(account:)
        raise NotImplementedError, "#{self.class} doit implémenter #save"
      end
    end
  end
end
