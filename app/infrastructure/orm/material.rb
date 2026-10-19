# 🔌 INFRA · Orm::Material
# Rôle : table materials, matières ; la catégorie porte l'icône et la couleur
# ADR  : 0029, 0034, 0103
module Orm
  class Material < ApplicationRecord
    include HasFrozenSlug

    self.table_name = "materials"

    has_frozen_slug from: :name

    has_many :teacher_school_materials, class_name: "Orm::TeacherSchoolMaterial", inverse_of: :material,
                                        dependent: :restrict_with_error
    has_many :courses, class_name: "Orm::Course", inverse_of: :material, dependent: :restrict_with_error
  end
end
