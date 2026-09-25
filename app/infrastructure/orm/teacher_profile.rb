# 🔌 INFRA · Orm::TeacherProfile
# Rôle : table teacher_profiles, attributs du rôle enseignant (matière, fin d'onboarding)
# ADR  : 0027, 0030
module Orm
  class TeacherProfile < ApplicationRecord
    self.table_name = "teacher_profiles"

    belongs_to :user, class_name: "Orm::User", inverse_of: :teacher_profile
    belongs_to :material, class_name: "Orm::Material", inverse_of: :teacher_profiles
  end
end
