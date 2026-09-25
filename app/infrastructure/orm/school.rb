# 🔌 INFRA · Orm::School
# Rôle : table schools, établissements (public, privé, mixte) et leurs classes
# ADR  : 0029, 0030
module Orm
  class School < ApplicationRecord
    include HasPublicId

    self.table_name = "schools"

    belongs_to :drena, class_name: "Orm::Drena", inverse_of: :schools

    has_many :classrooms, class_name: "Orm::Classroom", inverse_of: :school, dependent: :restrict_with_error
    has_many :teacher_schools, class_name: "Orm::TeacherSchool", inverse_of: :school, dependent: :restrict_with_error
  end
end
