# 🔌 INFRA · Orm::Exercise
# Rôle : table exercises, exercices d'une fiche, adressés par public_id
# ADR  : 0029, 0035, 0054, 0113, 0121
module Orm
  class Exercise < ApplicationRecord
    include HasPublicId

    self.table_name = "exercises"

    belongs_to :course, class_name: "Orm::Course"
    # Facultative : un exercice de toute la leçon n'a pas de notion.
    belongs_to :essential, class_name: "Orm::Essential", inverse_of: :exercises, optional: true
    # Facultatif : le sujet de devoir de l'exercice ; un exercice de sujet n'a pas de notion (exercises_subject_without_essential).
    belongs_to :subject, class_name: "Orm::Subject", inverse_of: :exercises, optional: true
    belongs_to :author, class_name: "Orm::User"

    has_many :questions, -> { order(:position) }, class_name: "Orm::Question", inverse_of: :exercise,
                                                  dependent: :restrict_with_error
    has_many :exercise_sessions, class_name: "Orm::ExerciseSession", inverse_of: :exercise, dependent: :restrict_with_error
  end
end
