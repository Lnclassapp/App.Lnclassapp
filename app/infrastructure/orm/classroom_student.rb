# 🔌 INFRA · Orm::ClassroomStudent
# Rôle : table classroom_students, adhésions ; une ligne n'est jamais supprimée (left_at), le retrait s'y retient
# ADR  : 0036, 0040, 0083
module Orm
  class ClassroomStudent < ApplicationRecord
    self.table_name = "classroom_students"

    belongs_to :classroom, class_name: "Orm::Classroom", inverse_of: :classroom_students
    belongs_to :student, class_name: "Orm::User"
    belongs_to :removed_by, class_name: "Orm::User", optional: true
  end
end
