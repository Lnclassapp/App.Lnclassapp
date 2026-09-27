# 🔌 INFRA · Queries::Assessment::ExerciseProgressQuery
# Rôle : progression d'un élève sur un exercice : badge, meilleur score et maîtrise des sessions terminées, session en cours
# ADR  : 0033, 0054 · UDR : 0007
module Queries
  module Assessment
    class ExerciseProgressQuery
      # badge_level et mastery : symboles de Grading ; best_score_percent, mastery et started_session_public_id peuvent être nil.
      Row = Data.define(:badge_level, :best_score_percent, :mastery, :completed_count, :started_session_public_id)

      def call(student_id:, exercise_id:)
        sessions = Orm::ExerciseSession.where(student_id:, exercise_id:)
        best, completed_count = sessions.where(status: "completed")
                                        .pick(Arel.sql("MAX(score_percent)"), Arel.sql("COUNT(*)"))
        badge = Orm::ExerciseBadge.where(student_id:, exercise_id:).pick(:level)
        Row.new(badge_level: badge&.to_sym, best_score_percent: best, mastery: mastery(best), completed_count:,
                started_session_public_id: sessions.where(status: "started").pick(:public_id))
      end

      private

      def mastery(best)
        return if best.nil?

        Entities::Assessment::Grading.mastery_for(best)
      end
    end
  end
end
