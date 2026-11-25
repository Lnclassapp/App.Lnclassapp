# 🔌 INFRA · Queries::Communication::PushCandidates::LastActivity
# Rôle : la dernière activité de chaque élève (définition de l'entonnoir) ; lue par les motifs « inactif » et « résultat »
# ADR  : 0146 · 0126 (entonnoir) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class LastActivity
        # La plus récente de : lecture d'une notion, session d'exercice commencée ou terminée, réponse à une question.
        SQL = <<~SQL.squish.freeze
          SELECT u.id AS user_id,
                 GREATEST(
                   (SELECT MAX(r.last_read_at) FROM essential_reads r WHERE r.student_id = u.id),
                   (SELECT MAX(GREATEST(e.started_at, e.completed_at)) FROM exercise_sessions e WHERE e.student_id = u.id),
                   (SELECT MAX(a.answered_at) FROM question_attempts a JOIN exercise_sessions e ON e.id = a.exercise_session_id
                     WHERE e.student_id = u.id)
                 ) AS last_active_at
            FROM users u
           WHERE u.id IN (:user_ids) AND u.role = 'student' AND u.anonymized_at IS NULL
        SQL

        # → { user_id => Time } ; un élève sans aucune activité est absent.
        def at(user_ids:)
          return {} if user_ids.empty?

          sql = ActiveRecord::Base.sanitize_sql_array([ SQL, { user_ids: user_ids } ])
          ActiveRecord::Base.connection.select_rows(sql).each_with_object({}) do |(user_id, last_active_at), result|
            result[user_id] = last_active_at.in_time_zone("UTC") if last_active_at
          end
        end
      end
    end
  end
end
