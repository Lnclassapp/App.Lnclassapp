# 🔌 INFRA · Orm::Exercise
# Rôle : table exercises, exercices d'une fiche, adressés par public_id
# ADR  : 0029, 0035, 0054
module Orm
  class Exercise < ApplicationRecord
    include HasPublicId

    self.table_name = "exercises"

    belongs_to :essential, class_name: "Orm::Essential", inverse_of: :exercises
    belongs_to :author, class_name: "Orm::User"

    has_many :questions, -> { order(:position) }, class_name: "Orm::Question", inverse_of: :exercise,
                                                  dependent: :restrict_with_error
    has_many :exercise_sessions, class_name: "Orm::ExerciseSession", inverse_of: :exercise, dependent: :restrict_with_error
  end
end
