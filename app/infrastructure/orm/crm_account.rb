# 🔌 INFRA · Orm::CrmAccount
# Rôle : table crm_accounts, étape saisie et responsable d'une école ; une ligne par école, créée à la première écriture
# ADR  : XXXX (contexte crm)
module Orm
  class CrmAccount < ApplicationRecord
    self.table_name = "crm_accounts"

    belongs_to :school, class_name: "Orm::School"
    belongs_to :owner, class_name: "Orm::User", optional: true
  end
end
