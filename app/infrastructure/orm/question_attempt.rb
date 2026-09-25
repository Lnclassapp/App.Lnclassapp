# 🔌 INFRA · Orm::QuestionAttempt
# Rôle : table question_attempts, tentative immuable : une ligne enregistrée ne change plus
# ADR  : 0036, 0054
module Orm
  class QuestionAttempt < ApplicationRecord
    self.table_name = "question_attempts"

    belongs_to :exercise_session, class_name: "Orm::ExerciseSession", inverse_of: :question_attempts
    belongs_to :question, class_name: "Orm::Question", inverse_of: :question_attempts

    def readonly? = persisted? || super
  end
end
