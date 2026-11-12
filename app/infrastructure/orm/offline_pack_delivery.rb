# 🔌 INFRA · Orm::OfflinePackDelivery
# Rôle : table offline_pack_deliveries, la remise du corrigé hors ligne d'un exercice à un élève (première et dernière)
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, amendement « Devoir à rendre »)
module Orm
  class OfflinePackDelivery < ApplicationRecord
    self.table_name = "offline_pack_deliveries"

    belongs_to :student, class_name: "Orm::User"
    belongs_to :exercise, class_name: "Orm::Exercise"
  end
end
