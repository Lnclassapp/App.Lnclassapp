# 🔌 INFRA · Orm::ExerciseBadge
# Rôle : table exercise_badges, meilleur badge d'un élève sur un exercice
# ADR  : 0033
module Orm
  class ExerciseBadge < ApplicationRecord
    self.table_name = "exercise_badges"

    belongs_to :student, class_name: "Orm::User"
    belongs_to :exercise, class_name: "Orm::Exercise"
    belongs_to :exercise_session, class_name: "Orm::ExerciseSession"
  end
end
