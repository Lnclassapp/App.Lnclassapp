# 🔌 INFRA · Orm::CrmContact
# Rôle : table crm_contacts, personnes à appeler dans une école ; archivées, jamais supprimées
# ADR  : XXXX (contexte crm)
module Orm
  class CrmContact < ApplicationRecord
    include HasPublicId

    self.table_name = "crm_contacts"

    belongs_to :school, class_name: "Orm::School"
    belongs_to :created_by, class_name: "Orm::User"

    scope :active, -> { where(archived_at: nil) }
  end
end
