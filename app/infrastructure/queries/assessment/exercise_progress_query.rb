# 🔌 INFRA · Queries::Assessment::ExerciseProgressQuery
# Rôle : progression d'un élève sur un exercice : badge, meilleur score et maîtrise des sessions terminées, session en cours
# ADR  : 0033, 0054 · UDR : 0007, 0087
module Queries
  module Assessment
    class ExerciseProgressQuery
      # badge_level et mastery : symboles de Grading ; best_score_percent, mastery et started_session_public_id peuvent être nil.
      # resume_number : rang de la question où reprendre la session en cours (UDR-0087 §3.1), nil sans elle.
      Row = Data.define(:badge_level, :best_score_percent, :mastery, :completed_count, :started_session_public_id, :resume_number) do
        def initialize(resume_number: nil, **) = super
      end

      def call(student_id:, exercise_id:)
        sessions = Orm::ExerciseSession.where(student_id:, exercise_id:)
        best, completed_count = sessions.where(status: "completed")
                                        .pick(Arel.sql("MAX(score_percent)"), Arel.sql("COUNT(*)"))
        badge = Orm::ExerciseBadge.where(student_id:, exercise_id:).pick(:level)
        started_public_id, answered_count = sessions.where(status: "started").pick(:public_id, :answered_count)
        Row.new(badge_level: badge&.to_sym, best_score_percent: best, mastery: mastery(best), completed_count:,
                started_session_public_id: started_public_id, resume_number: answered_count&.succ)
      end

      private

      def mastery(best)
        return if best.nil?

        Entities::Assessment::Grading.mastery_for(best)
      end
    end
  end
end
