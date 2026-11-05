# 🔌 INFRA · Repositories::Crm::ContactRepository
# Rôle : lit et écrit les contacts d'une école (table crm_contacts) ; le retrait est un archivage, jamais une suppression
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class ContactRepository
      include Ports::Crm::ContactRepositoryPort

      def active_for_school(school_id:)
        Orm::CrmContact.active.where(school_id:).order(Arel.sql("lower(full_name)"), :id).map { to_entity(it) }
      end

      def find_by_public_id(public_id:)
        record = Orm::CrmContact.find_by(public_id:)
        to_entity(record) if record
      end

      # Un numéro mal formé est refusé ici avant l'écriture (la base le refuse aussi : crm_contacts_phone_format).
      def create(contact:)
        if contact.phone && !contact.phone.match?(Entities::Crm::Contact::PHONE_FORMAT)
          return ::Shared::Result.failure(:invalid, errors: { phone: [ :invalid ] })
        end

        record = Orm::CrmContact.create!(school_id: contact.school_id, full_name: contact.full_name, position: contact.position,
                                         phone: contact.phone, note: contact.note, created_by_id: contact.created_by_id)
        ::Shared::Result.success(to_entity(record))
      end

      def archive(public_id:, at:)
        record = Orm::CrmContact.find_by(public_id:)
        return ::Shared::Result.failure(:not_found) if record.nil?

        record.update!(archived_at: at) if record.archived_at.nil?
        ::Shared::Result.success(to_entity(record))
      end

      private

      def to_entity(record)
        Entities::Crm::Contact.new(public_id: record.public_id, school_id: record.school_id, full_name: record.full_name,
                                   position: record.position, phone: record.phone, note: record.note,
                                   created_by_id: record.created_by_id, archived_at: record.archived_at)
      end
    end
  end
end
