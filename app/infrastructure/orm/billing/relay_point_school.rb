# 🔌 INFRA · Orm::Billing::RelayPointSchool
# Rôle : table billing_relay_point_schools, les écoles qu'un point relais dessert (une paire, une fois)
# ADR  : 0126 (contexte billing, §4.1)
module Orm
  module Billing
    class RelayPointSchool < ApplicationRecord
      self.table_name = "billing_relay_point_schools"

      belongs_to :relay_point, class_name: "Orm::Billing::RelayPoint", inverse_of: :relay_point_schools
      belongs_to :school, class_name: "Orm::School"
    end
  end
end
