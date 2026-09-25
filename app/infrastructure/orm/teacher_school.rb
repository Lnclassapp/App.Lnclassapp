# 🔌 INFRA · Orm::TeacherSchool
# Rôle : table teacher_schools, établissement d'un enseignant (une seule école principale)
# ADR  : 0030
module Orm
  class TeacherSchool < ApplicationRecord
    self.table_name = "teacher_schools"

    belongs_to :teacher, class_name: "Orm::User"
    belongs_to :school, class_name: "Orm::School", inverse_of: :teacher_schools
  end
end
