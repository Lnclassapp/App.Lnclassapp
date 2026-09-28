# 🧠 DOMAINE · Ports::School::JoinRequestRepositoryPort
# Rôle : contrat des demandes d'enseignants inscrits sans code : création, plafond, décision qui rattache l'enseignant
# ADR  : 0063
module Ports
  module School
    module JoinRequestRepositoryPort
      # Une seule demande par enseignant. → Result(Entities::School::JoinRequest) | failure(:conflict)
      def create(teacher_id:, school_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Integer
      def pending_count(school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #pending_count"
      end

      # → Entities::School::JoinRequest | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Décide une demande encore en attente et rattache l'enseignant (école principale), en une écriture.
      # via : "team" | "sponsor". → Result | failure(:conflict, errors: { base: [:already_decided] })
      def approve(id:, decided_by_id:, via:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #approve"
      end

      # → Result | failure(:conflict, errors: { base: [:already_decided] })
      def reject(id:, decided_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #reject"
      end
    end
  end
end
