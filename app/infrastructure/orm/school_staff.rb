# 🔌 INFRA · Orm::SchoolStaff
# Rôle : table school_staffs, rattachement d'un compte de la direction à un établissement, avec sa fonction ; jamais supprimé
# ADR  : 0044, 0066
module Orm
  class SchoolStaff < ApplicationRecord
    self.table_name = "school_staffs"

    belongs_to :user, class_name: "Orm::User", inverse_of: :school_staffs
    belongs_to :school, class_name: "Orm::School"
    belongs_to :invited_by, class_name: "Orm::User", optional: true

    scope :active, -> { where(left_at: nil) }
  end
end
