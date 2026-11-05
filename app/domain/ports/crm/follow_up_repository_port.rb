# 🧠 DOMAINE · Ports::Crm::FollowUpRepositoryPort
# Rôle : contrat des relances : créer, lire, terminer (sans effet si déjà faite), réattribuer
# ADR  : XXXX (contexte crm) · gelé par le Lot 0
module Ports
  module Crm
    module FollowUpRepositoryPort
      # → Result(FollowUp) ouverte, avec son public_id | failure(:not_found) si interaction_public_id ne désigne aucun échange de cette école
      def create(follow_up:, interaction_public_id: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Entities::Crm::FollowUp | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # → Result(FollowUp) | failure(:not_found) ; une relance déjà faite est rendue telle quelle, sans erreur
      def complete(public_id:, by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #complete"
      end

      # → Result(FollowUp) | failure(:not_found)
      def reassign(public_id:, assignee_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #reassign"
      end
    end
  end
end
