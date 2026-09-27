# 🔌 INFRA · Orm::Question
# Rôle : table questions, questions d'un exercice et leurs propositions ordonnées
# ADR  : 0054
module Orm
  class Question < ApplicationRecord
    self.table_name = "questions"

    belongs_to :exercise, class_name: "Orm::Exercise", inverse_of: :questions

    has_many :answers, -> { order(:position) }, class_name: "Orm::Answer", inverse_of: :question,
                                                dependent: :restrict_with_error
    has_many :question_attempts, class_name: "Orm::QuestionAttempt", inverse_of: :question, dependent: :restrict_with_error
  end
end
