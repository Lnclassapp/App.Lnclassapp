# 🔌 INFRA · Orm::TeacherClassroom
# Rôle : table teacher_classrooms, classes qu'un enseignant déclare enseigner
# ADR  : 0030
module Orm
  class TeacherClassroom < ApplicationRecord
    self.table_name = "teacher_classrooms"

    belongs_to :teacher, class_name: "Orm::User"
    belongs_to :classroom, class_name: "Orm::Classroom", inverse_of: :teacher_classrooms
  end
end
