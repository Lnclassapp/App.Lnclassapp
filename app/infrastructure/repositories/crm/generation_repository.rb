# 🔌 INFRA · Repositories::Crm::GenerationRepository
# Rôle : squelette du Lot 0 (adaptateur de Ports::Crm::GenerationRepositoryPort), complété par le Lot G
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class GenerationRepository
      include Ports::Crm::GenerationRepositoryPort

      def create_pending(generation:)
        raise NotImplementedError, "Lot G"
      end

      def find_by_public_id(public_id:)
        raise NotImplementedError, "Lot G"
      end

      def pending_for(school_id:, kind:)
        raise NotImplementedError, "Lot G"
      end

      def latest_done(school_id:, kind:, input_fingerprint:)
        raise NotImplementedError, "Lot G"
      end

      def complete(public_id:, content:, model:, input_tokens:, output_tokens:, duration_ms:)
        raise NotImplementedError, "Lot G"
      end

      def mark_failed(public_id:, error_code:, duration_ms:)
        raise NotImplementedError, "Lot G"
      end
    end
  end
end
