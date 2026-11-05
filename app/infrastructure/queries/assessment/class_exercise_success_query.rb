# 🔌 INFRA · Queries::Assessment::ClassExerciseSuccessQuery
# Rôle : la réussite de la classe sur chaque exercice d'une feuille (meilleure copie par élève, seuil de réussite actuel)
# ADR  : lecture-de-la-classe-par-la-direction · UDR : suivi-de-la-classe-sur-une-lecon §3.2
module Queries
  module Assessment
    class ClassExerciseSuccessQuery
      # exercise_ids = les public_id des exercices de la feuille. Les élèves sont les présents de la classe (comme le suivi des
      # devoirs, ADR-0072 §4.4) ; les copies sont les terminées, de toute sorte, devoir ou exercice libre. Deux requêtes pour toute la feuille.
      # → { exercise public_id => Entities::Assessment::ClassSuccess }
      def call(classroom_public_id:, exercise_ids:)
        return {} if exercise_ids.empty?

        classroom_id = Orm::Classroom.where(public_id: classroom_public_id).pick(:id)
        return {} if classroom_id.nil?

        present = Queries::Classroom::AssignmentFollowUpQuery.present_students(classroom_id).select(:student_id)
        scores = Orm::ExerciseSession.joins(:exercise).where(status: "completed", student_id: present, exercises: { public_id: exercise_ids })
                                     .pluck("exercises.public_id", :student_id, :score_percent)
                                     .group_by(&:first)
        present_count = Queries::Classroom::AssignmentFollowUpQuery.present_students(classroom_id).count

        exercise_ids.to_h do |id|
          by_student = scores.fetch(id, []).group_by { it[1] }.transform_values { |rows| rows.map(&:last) }
          [ id, Entities::Assessment::ClassSuccess.build(exercise_id: id, present_count:, scores_by_student: by_student) ]
        end
      end
    end
  end
end
