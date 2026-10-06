# 🔌 INFRA · Queries::Assessment::AssignmentScores
# Rôle : lecture socle de la compréhension : scores des sessions faites (remédiation comprise) de chaque élève présent, sa première et sa meilleure session
# ADR  : 0026, 0048, 0072, 0079 · une requête, quel que soit le nombre d'assignations ou d'élèves ; aucun cache
module Queries
  module Assessment
    module AssignmentScores
      # scores : score_percent des sessions faites, ordre (completed_at, id) ; first_session_id : la première ;
      # best_session_id : la session de score maximal, la plus récente à égalité (ADR-0079 §4.5).
      StudentScores = Data.define(:student_id, :scores, :first_session_id, :best_session_id)

      # → { assignment_id => [StudentScores] } ; une assignation que personne n'a faite est absente.
      # « Fait » et « présent » : la définition de l'ADR-0072 §4.4, lue sur AssignmentFollowUpQuery.present_students.
      # Une session de remédiation sur l'exercice assigné, c'est faire cet exercice : elle compte (ADR-0079 §4.1).
      # Index : index_exercise_sessions_on_classroom_assignment_id (le partiel handed_in ne couvre que kind = 'standard').
      def self.for(classroom_id:, assignment_ids:)
        return {} if assignment_ids.empty?

        Orm::ExerciseSession.where(classroom_assignment_id: assignment_ids, status: "completed",
                                   student_id: Queries::Classroom::AssignmentFollowUpQuery.present_students(classroom_id).select(:student_id))
                            .order(:classroom_assignment_id, :student_id, :completed_at, :id)
                            .pluck(:classroom_assignment_id, :student_id, :id, :score_percent)
                            .group_by(&:first)
                            .transform_values { |rows| rows.group_by(&:second).map { |student_id, sessions| scores(student_id, sessions) } }
      end

      # sessions : [assignment_id, student_id, id, score_percent], dans l'ordre (completed_at, id).
      def self.scores(student_id, sessions)
        best = sessions.reverse.max_by(&:last)
        StudentScores.new(student_id:, scores: sessions.map(&:last), first_session_id: sessions.first[2], best_session_id: best[2])
      end
      private_class_method :scores
    end
  end
end
