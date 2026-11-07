# 🔌 INFRA · Orm::Billing::Remittance
# Rôle : table billing_remittances, les versements d'un point relais ; jamais modifiés ni supprimés
# ADR  : cartes-activation (contexte billing, §4.1)
module Orm
  module Billing
    class Remittance < ApplicationRecord
      include Orm::HasPublicId

      self.table_name = "billing_remittances"

      belongs_to :relay_point, class_name: "Orm::Billing::RelayPoint", inverse_of: :remittances
      belongs_to :recorded_by, class_name: "Orm::User", optional: true

      before_update { throw :abort }
      before_destroy { throw :abort }
    end
  end
end
