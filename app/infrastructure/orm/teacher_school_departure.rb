# 🔌 INFRA · Orm::TeacherSchoolDeparture
# Rôle : table teacher_school_departures, retrait d'un enseignant par la direction ; ouvert tant qu'il n'est pas réintégré
# ADR  : 0066
module Orm
  class TeacherSchoolDeparture < ApplicationRecord
    self.table_name = "teacher_school_departures"

    belongs_to :teacher, class_name: "Orm::User"
    belongs_to :school, class_name: "Orm::School"
    belongs_to :detached_by, class_name: "Orm::User"
    belongs_to :reinstated_by, class_name: "Orm::User", optional: true

    scope :not_reinstated, -> { where(reinstated_at: nil) }
  end
end
