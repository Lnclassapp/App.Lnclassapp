# 🔌 INFRA · Orm::ExerciseSession
# Rôle : table exercise_sessions, passage d'un élève sur un exercice
# ADR  : 0029, 0033, 0043, 0048, 0054
module Orm
  class ExerciseSession < ApplicationRecord
    include HasPublicId

    self.table_name = "exercise_sessions"

    belongs_to :student, class_name: "Orm::User"
    belongs_to :exercise, class_name: "Orm::Exercise", inverse_of: :exercise_sessions
    belongs_to :classroom_assignment, class_name: "Orm::ClassroomAssignment", optional: true
    belongs_to :knowledge_gap, class_name: "Orm::KnowledgeGap", optional: true

    has_many :question_attempts, class_name: "Orm::QuestionAttempt", inverse_of: :exercise_session,
                                 dependent: :restrict_with_error
  end
end
