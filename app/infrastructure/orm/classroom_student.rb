# 🔌 INFRA · Orm::ClassroomStudent
# Rôle : table classroom_students, adhésions ; une ligne n'est jamais supprimée (left_at)
# ADR  : 0036, 0040
module Orm
  class ClassroomStudent < ApplicationRecord
    self.table_name = "classroom_students"

    belongs_to :classroom, class_name: "Orm::Classroom", inverse_of: :classroom_students
    belongs_to :student, class_name: "Orm::User"
  end
end
