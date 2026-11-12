# 🔌 INFRA · Orm::CrmGeneration
# Rôle : table crm_generations, générations des modèles de langage ; la pièce audio d'une dictée, privée, purgée en fin de job
# ADR  : XXXX (modèles de langage), XXXX (contexte crm)
module Orm
  class CrmGeneration < ApplicationRecord
    include HasPublicId

    self.table_name = "crm_generations"

    belongs_to :school, class_name: "Orm::School"
    belongs_to :requested_by, class_name: "Orm::User"
    belongs_to :follow_up, class_name: "Orm::CrmFollowUp", optional: true

    has_one_attached :audio
  end
end
