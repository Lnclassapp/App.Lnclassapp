# 🔌 INFRA · Repositories::Assessment::LearningDataEraser
# Rôle : efface ligne par ligne les sessions, réponses, badges et lacunes d'un élève supprimé, dans l'ordre des clés restrict
# ADR  : 0036 (amendement 2), 0043
module Repositories
  module Assessment
    class LearningDataEraser
      include Ports::Assessment::LearningDataEraserPort

      # Les clés sont en `restrict` et circulaires : une session de remédiation pointe sa lacune (knowledge_gap_id), une
      # lacune pointe la session qui l'a ouverte (source_session_id, obligatoire) et celle qui l'a résolue (facultative).
      # L'ordre casse le cycle : d'abord les références facultatives, puis les feuilles, enfin les sessions.
      #
      # Seule écriture hors des lignes de l'élève : la lacune d'un autre élève résolue par l'une de ses sessions perd cette
      # référence (colonne nullable), elle reste résolue. Les autres liens vers un autre élève (lacune ouverte par sa session,
      # session de remédiation sur sa lacune, badge gagné par sa session) ne se forment pas : une lacune, une remédiation et un
      # badge appartiennent à l'élève de leur session (CloseExerciseSession, StartExerciseSession). S'ils existaient, la clé
      # restrict refuserait l'effacement et la transaction de l'anonymisation laisserait tout intact.
      def erase_for(student_id:)
        sessions = Orm::ExerciseSession.where(student_id:)
        gaps = Orm::KnowledgeGap.where(student_id:)

        Orm::KnowledgeGap.where(resolved_by_session_id: sessions.select(:id)).update_all(resolved_by_session_id: nil)
        # Le contrôle `remediation ⇔ lacune` impose de rendre la session « standard » en même temps : elle part juste après.
        sessions.where.not(knowledge_gap_id: nil).update_all(kind: "standard", knowledge_gap_id: nil)
        Orm::QuestionAttempt.where(exercise_session_id: sessions.select(:id)).delete_all
        Orm::ExerciseBadge.where(student_id:).delete_all
        gaps.delete_all
        sessions.delete_all
        true
      end
    end
  end
end
