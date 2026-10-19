# 🔌 INFRA · Orm::TeacherSchoolMaterial
# Rôle : table teacher_school_materials, matières d'un enseignant dans un établissement (1 à 3, ordre d'ajout)
# ADR  : 0094 (§10), 0103
module Orm
  class TeacherSchoolMaterial < ApplicationRecord
    self.table_name = "teacher_school_materials"

    belongs_to :teacher, class_name: "Orm::User"
    belongs_to :school, class_name: "Orm::School"
    belongs_to :material, class_name: "Orm::Material", inverse_of: :teacher_school_materials

    # ADR-0103 §4.1 : l'ordre d'ajout, la matière de l'inscription en tête ; l'id départage un même instant.
    scope :in_order, -> { order(:created_at, :id) }
  end
end
