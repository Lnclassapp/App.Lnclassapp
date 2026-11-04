# 🧠 DOMAINE · Ports::Crm::ContactRepositoryPort
# Rôle : contrat des contacts d'une école ; retrait = archivage, jamais de suppression
# ADR  : XXXX (contexte crm) · gelé par le Lot 0
module Ports
  module Crm
    module ContactRepositoryPort
      # → [Entities::Crm::Contact] non archivés, par nom
      def active_for_school(school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #active_for_school"
      end

      # → Entities::Crm::Contact | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # → Result(Contact) | failure(:invalid, errors: { phone: [:invalid] })
      def create(contact:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Result(Contact) | failure(:not_found) ; archiver un contact déjà archivé est sans effet
      def archive(public_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archive"
      end
    end
  end
end
