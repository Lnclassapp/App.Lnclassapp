# 🔌 INFRA · Repositories::Crm::AccountRepository
# Rôle : squelette du Lot 0 (adaptateur de Ports::Crm::AccountRepositoryPort), complété par le Lot A
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class AccountRepository
      include Ports::Crm::AccountRepositoryPort

      def find_by_school_id(school_id:)
        raise NotImplementedError, "Lot A"
      end

      def save(account:)
        raise NotImplementedError, "Lot A"
      end
    end
  end
end
