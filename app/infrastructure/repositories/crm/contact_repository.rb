# 🔌 INFRA · Repositories::Crm::ContactRepository
# Rôle : squelette du Lot 0 (adaptateur de Ports::Crm::ContactRepositoryPort), complété par le Lot B
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class ContactRepository
      include Ports::Crm::ContactRepositoryPort

      def active_for_school(school_id:)
        raise NotImplementedError, "Lot B"
      end

      def find_by_public_id(public_id:)
        raise NotImplementedError, "Lot B"
      end

      def create(contact:)
        raise NotImplementedError, "Lot B"
      end

      def archive(public_id:, at:)
        raise NotImplementedError, "Lot B"
      end
    end
  end
end
