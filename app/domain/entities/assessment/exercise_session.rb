# 🧠 DOMAINE · Entities::Assessment::ExerciseSession
# Rôle : une passation d'exercice par un élève ; score posé seulement à la clôture
# ADR  : 0033, 0043, 0048, 0054
module Entities
  module Assessment
    ExerciseSession = Data.define(:id, :public_id, :student_id, :exercise_id, :status, :question_count, :answered_count,
                                  :correct_count, :progress_percent, :score_percent, :kind, :knowledge_gap_id,
                                  :classroom_assignment_id, :started_at, :completed_at) do
      def started? = status == "started"
      def completed? = status == "completed"
      def remediation? = kind == "remediation"
      def complete? = answered_count == question_count
    end
    ExerciseSession::STATUSES = %w[started completed abandoned].freeze
    ExerciseSession::KINDS = %w[standard remediation].freeze
  end
end
