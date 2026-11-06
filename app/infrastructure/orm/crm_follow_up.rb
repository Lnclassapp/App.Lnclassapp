# 🔌 INFRA · Orm::CrmFollowUp
# Rôle : table crm_follow_ups, relances d'une école confiées à un membre de l'équipe
# ADR  : XXXX (contexte crm)
module Orm
  class CrmFollowUp < ApplicationRecord
    include HasPublicId

    self.table_name = "crm_follow_ups"

    belongs_to :school, class_name: "Orm::School"
    belongs_to :assignee, class_name: "Orm::User"
    belongs_to :done_by, class_name: "Orm::User", optional: true
    belongs_to :created_by, class_name: "Orm::User"
    belongs_to :interaction, class_name: "Orm::CrmInteraction", optional: true

    scope :open, -> { where(status: "open") }
  end
end
