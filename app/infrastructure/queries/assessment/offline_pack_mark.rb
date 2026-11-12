# 🔌 INFRA · Queries::Assessment::OfflinePackMark
# Rôle : la marque « corrigé reçu avant la copie » : copie rattachée à un devoir, commencée après la première remise du corrigé hors ligne ; calculée à la lecture
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, amendement « Devoir à rendre ») · UDR : 0170 §3.8 · menace C1 · une requête, quel que soit le nombre d'élèves
module Queries
  module Assessment
    module OfflinePackMark
      JOIN = "JOIN offline_pack_deliveries ON offline_pack_deliveries.student_id = exercise_sessions.student_id " \
             "AND offline_pack_deliveries.exercise_id = exercise_sessions.exercise_id " \
             "AND exercise_sessions.started_at > offline_pack_deliveries.first_delivered_at".freeze

      # Colonne à lire avec la session (aucune requête de plus) : la première remise si la copie, rattachée à un devoir, l'a suivie, sinon NULL.
      SESSION_COLUMN = "(SELECT offline_pack_deliveries.first_delivered_at FROM offline_pack_deliveries " \
                       "WHERE exercise_sessions.classroom_assignment_id IS NOT NULL " \
                       "AND offline_pack_deliveries.student_id = exercise_sessions.student_id " \
                       "AND offline_pack_deliveries.exercise_id = exercise_sessions.exercise_id " \
                       "AND exercise_sessions.started_at > offline_pack_deliveries.first_delivered_at)".freeze

      # → { student_id => première remise } pour les élèves d'une assignation dont une copie rendue sur ce devoir est marquée.
      def self.by_student(assignment_id)
        Orm::ExerciseSession.joins(JOIN).where(classroom_assignment_id: assignment_id, status: "completed")
                            .group(:student_id).pluck(:student_id, "MIN(offline_pack_deliveries.first_delivered_at)").to_h
      end
    end
  end
end
