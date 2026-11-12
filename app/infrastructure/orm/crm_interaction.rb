# 🔌 INFRA · Orm::CrmInteraction
# Rôle : table crm_interactions, journal des échanges d'une école ; ajout seul
# ADR  : XXXX (contexte crm)
module Orm
  class CrmInteraction < ApplicationRecord
    include HasPublicId

    self.table_name = "crm_interactions"

    belongs_to :school, class_name: "Orm::School"
    belongs_to :author, class_name: "Orm::User"
    belongs_to :contact, class_name: "Orm::CrmContact", optional: true
  end
end
