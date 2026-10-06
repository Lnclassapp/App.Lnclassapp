# 🧠 DOMAINE · Ports::Identity::DeletionRequestRepositoryPort
# Rôle : contrat des demandes de suppression : une seule en attente par compte, close une fois traitée ou annulée
# ADR  : 0036 (amendement 2 du 2026-10-02)
module Ports
  module Identity
    module DeletionRequestRepositoryPort
      # → Entities::Identity::DeletionRequest | nil
      def pending_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #pending_for"
      end

      # Une demande déjà en attente pour ce compte, même écrite en concurrence, donne :conflict sans casser la transaction.
      # → Result(Entities::Identity::DeletionRequest) | failure(:conflict, errors: { base: [:already_pending] })
      def record(user_id:, requested_on:, recorded_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      # Clôt la demande en attente du compte : status ∈ "processed", "cancelled".
      # → Entities::Identity::DeletionRequest close (son nouvel état) | nil s'il n'y en avait pas
      def close(user_id:, status:, closed_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #close"
      end
    end
  end
end
