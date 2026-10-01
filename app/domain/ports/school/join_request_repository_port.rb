# 🧠 DOMAINE · Ports::School::JoinRequestRepositoryPort
# Rôle : contrat des demandes d'enseignants inscrits sans code : création, plafond, décision qui rattache l'enseignant
# ADR  : 0063, 0071
module Ports
  module School
    module JoinRequestRepositoryPort
      # Une seule demande par enseignant ; au plus max_pending demandes en attente par école, compté et écrit sous verrou.
      # → Result(Entities::School::JoinRequest) | failure(:conflict) | failure(:invalid, errors: { base: [:too_many_pending] })
      def create(teacher_id:, school_id:, at:, max_pending:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Entities::School::JoinRequest | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # La demande de l'enseignant tant qu'elle est en attente (ADR-0071 : un enseignant en attente ne rejoint pas par code).
      # → Entities::School::JoinRequest | nil
      def pending_for(teacher_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #pending_for"
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
