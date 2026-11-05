# 🧠 DOMAINE · Ports::Crm::GenerationRepositoryPort
# Rôle : contrat des générations des modèles de langage ; une seule en cours par école et par type
# ADR  : XXXX (modèles de langage) · gelé par le Lot 0
module Ports
  module Crm
    module GenerationRepositoryPort
      # → Result(Generation) | failure(:conflict) si une génération du même type est déjà en cours pour l'école
      def create_pending(generation:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_pending"
      end

      # → Entities::Crm::Generation | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # → Entities::Crm::Generation | nil
      def pending_for(school_id:, kind:)
        raise NotImplementedError, "#{self.class} doit implémenter #pending_for"
      end

      # Dernière génération terminée dont l'empreinte des entrées est inchangée. → Generation | nil
      def latest_done(school_id:, kind:, input_fingerprint:)
        raise NotImplementedError, "#{self.class} doit implémenter #latest_done"
      end

      # → Result(Generation) | failure(:not_found) | failure(:conflict) si la génération n'est plus en attente (jamais écrasée)
      def complete(public_id:, content:, model:, input_tokens:, output_tokens:, duration_ms:)
        raise NotImplementedError, "#{self.class} doit implémenter #complete"
      end

      # error_code ∈ Generation::ERROR_CODES. → Result(Generation) | failure(:not_found) | failure(:conflict) si la génération n'est plus en attente
      def mark_failed(public_id:, error_code:, duration_ms:)
        raise NotImplementedError, "#{self.class} doit implémenter #mark_failed"
      end

      # Ferme (`failed`, error_code "timeout") les générations encore en attente créées avant `before`, et purge leur audio.
      # school_id / kind nil : toutes les écoles / tous les types. → Integer (nombre de lignes fermées)
      def fail_stale(school_id:, kind:, before:)
        raise NotImplementedError, "#{self.class} doit implémenter #fail_stale"
      end
    end
  end
end
