# 🔌 INFRA · Repositories::Assessment::BadgeRepository
# Rôle : meilleur badge d'un élève par exercice, une ligne par couple (élève, exercice)
# ADR  : 0033
module Repositories
  module Assessment
    class BadgeRepository
      include Ports::Assessment::BadgeRepositoryPort

      def find(student_id:, exercise_id:)
        record = Orm::ExerciseBadge.find_by(student_id:, exercise_id:)
        record && Entities::Assessment::Badge.new(student_id: record.student_id, exercise_id: record.exercise_id,
                                                  session_id: record.exercise_session_id, level: record.level.to_sym,
                                                  awarded_at: record.awarded_at)
      end

      # Le domaine ne remplace un badge que par un palier supérieur (Grading.upgrade?).
      def upsert(badge:)
        Orm::ExerciseBadge.upsert(
          { student_id: badge.student_id, exercise_id: badge.exercise_id, exercise_session_id: badge.session_id,
            level: badge.level.to_s, awarded_at: badge.awarded_at },
          unique_by: %i[student_id exercise_id], update_only: %i[exercise_session_id level awarded_at]
        )
        badge
      end
    end
  end
end
