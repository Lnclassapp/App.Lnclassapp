# 🔌 INFRA · Repositories::Crm::InteractionRepository
# Rôle : squelette du Lot 0 (adaptateur de Ports::Crm::InteractionRepositoryPort), complété par le Lot C
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class InteractionRepository
      include Ports::Crm::InteractionRepositoryPort

      def recent_for_school(school_id:, limit:, offset:)
        raise NotImplementedError, "Lot C"
      end

      def create(interaction:)
        raise NotImplementedError, "Lot C"
      end
    end
  end
end
