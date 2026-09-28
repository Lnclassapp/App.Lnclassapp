# 🔌 INFRA · Orm::ClassroomPlanEntry
# Rôle : table classroom_plan_entries, barème des classes générées par type d'établissement, niveau et série
# ADR  : 0058
module Orm
  class ClassroomPlanEntry < ApplicationRecord
    self.table_name = "classroom_plan_entries"

    belongs_to :level, class_name: "Orm::Level"
    belongs_to :series, class_name: "Orm::Series", optional: true
  end
end
