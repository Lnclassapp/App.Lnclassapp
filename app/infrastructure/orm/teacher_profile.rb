# 🔌 INFRA · Orm::TeacherProfile
# Rôle : table teacher_profiles, attributs du rôle enseignant (voie d'arrivée, parrainage, fin d'onboarding) ; ses matières : teacher_school_materials
# ADR  : 0027, 0030, 0103
module Orm
  class TeacherProfile < ApplicationRecord
    self.table_name = "teacher_profiles"

    belongs_to :user, class_name: "Orm::User", inverse_of: :teacher_profile
  end
end
