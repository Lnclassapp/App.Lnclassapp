# 🔌 INFRA · Orm::Billing::RelayPoint
# Rôle : table billing_relay_points, les points relais qui vendent les cartes d'activation en espèces
# ADR  : cartes-activation (contexte billing, §4.1)
module Orm
  module Billing
    class RelayPoint < ApplicationRecord
      include Orm::HasPublicId

      self.table_name = "billing_relay_points"

      has_many :relay_point_schools, class_name: "Orm::Billing::RelayPointSchool", foreign_key: :relay_point_id,
                                     inverse_of: :relay_point, dependent: :delete_all
      has_many :schools, through: :relay_point_schools, class_name: "Orm::School"
      has_many :card_batches, class_name: "Orm::Billing::CardBatch", foreign_key: :relay_point_id, inverse_of: :relay_point,
                              dependent: :restrict_with_error
      has_many :remittances, class_name: "Orm::Billing::Remittance", foreign_key: :relay_point_id, inverse_of: :relay_point,
                             dependent: :restrict_with_error
    end
  end
end
