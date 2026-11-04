# 🧠 DOMAINE · Ports::Crm::InteractionRepositoryPort
# Rôle : contrat du journal des échanges d'une école ; ajout seul
# ADR  : XXXX (contexte crm) · gelé par le Lot 0
module Ports
  module Crm
    module InteractionRepositoryPort
      # → [Entities::Crm::Interaction], du plus récent au plus ancien
      def recent_for_school(school_id:, limit:, offset:)
        raise NotImplementedError, "#{self.class} doit implémenter #recent_for_school"
      end

      # → Result(Interaction) ; aucune méthode de modification ni de suppression
      def create(interaction:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end
    end
  end
end
