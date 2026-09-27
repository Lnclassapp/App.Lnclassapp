# 🔌 INFRA · Orm::Classroom
# Rôle : table classrooms ; aucune association polymorphe vers les ressources assignées
# ADR  : 0029, 0036, 0041
module Orm
  class Classroom < ApplicationRecord
    include HasPublicId

    self.table_name = "classrooms"

    belongs_to :school, class_name: "Orm::School", inverse_of: :classrooms
    belongs_to :level, class_name: "Orm::Level"
    belongs_to :series, class_name: "Orm::Series", optional: true

    has_many :classroom_students, class_name: "Orm::ClassroomStudent", inverse_of: :classroom, dependent: :restrict_with_error
    has_many :teacher_classrooms, class_name: "Orm::TeacherClassroom", inverse_of: :classroom, dependent: :restrict_with_error
    has_many :classroom_assignments, class_name: "Orm::ClassroomAssignment", inverse_of: :classroom,
                                     dependent: :restrict_with_error
  end
end
