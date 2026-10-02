# 🔌 INFRA · Orm::ClassroomSessionDay
# Rôle : table classroom_session_days, un jour de séance (1 à 6) d'un enseignant dans une classe qu'il déclare
# ADR  : 0072
module Orm
  class ClassroomSessionDay < ApplicationRecord
    self.table_name = "classroom_session_days"

    belongs_to :teacher, class_name: "Orm::User"
    belongs_to :classroom, class_name: "Orm::Classroom"
  end
end
