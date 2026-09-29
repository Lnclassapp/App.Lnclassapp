# 🔌 INFRA · Orm::SchoolStaff
# Rôle : table school_staffs, rattachement d'un compte de direction à son seul établissement
# ADR  : 0036, 0065
module Orm
  class SchoolStaff < ApplicationRecord
    self.table_name = "school_staffs"

    belongs_to :user, class_name: "Orm::User", inverse_of: :school_staff
    belongs_to :school, class_name: "Orm::School"
    belongs_to :invited_by, class_name: "Orm::User", optional: true
  end
end
