# 🔌 INFRA · Queries::Crm::SchoolUsageQuery
# Rôle : usage réel d'un lot d'écoles (comptes rattachés, élèves actifs sur 14 jours, dernière activité, premier rattachement)
# ADR  : XXXX (contexte crm) · mêmes définitions que TeamDashboardQuery ; trois requêtes, quel que soit le nombre d'écoles
module Queries
  module Crm
    class SchoolUsageQuery
      # Comptes rattachés, non anonymisés : enseignants, directions non archivées, élèves placés (classe principale, active, de l'année).
      ATTACHMENTS = <<~SQL.squish.freeze
        SELECT teacher_schools.school_id AS school_id, teacher_schools.teacher_id AS user_id, teacher_schools.created_at AS attached_at
        FROM teacher_schools JOIN users ON users.id = teacher_schools.teacher_id
        WHERE teacher_schools.school_id IN (:ids) AND users.anonymized_at IS NULL
        UNION ALL
        SELECT school_staffs.school_id, school_staffs.user_id, school_staffs.created_at
        FROM school_staffs JOIN users ON users.id = school_staffs.user_id
        WHERE school_staffs.school_id IN (:ids) AND school_staffs.archived_at IS NULL AND users.anonymized_at IS NULL
        UNION ALL
        SELECT classrooms.school_id, classroom_students.student_id, classroom_students.joined_at
        FROM classroom_students
        JOIN classrooms ON classrooms.id = classroom_students.classroom_id
        JOIN users ON users.id = classroom_students.student_id
        WHERE classrooms.school_id IN (:ids) AND classroom_students."primary" AND classroom_students.left_at IS NULL
          AND classrooms.status = 'active' AND classrooms.school_year = :year AND users.anonymized_at IS NULL
      SQL

      ACCOUNTS = "SELECT school_id, COUNT(DISTINCT user_id), MIN(attached_at) FROM (#{ATTACHMENTS}) attachments GROUP BY school_id".freeze

      SESSIONS = <<~SQL.squish.freeze
        SELECT classrooms.school_id, MAX(exercise_sessions.started_at),
               COUNT(DISTINCT exercise_sessions.student_id) FILTER (WHERE exercise_sessions.started_at >= :since)
        FROM exercise_sessions
        JOIN classroom_students ON classroom_students.student_id = exercise_sessions.student_id
          AND classroom_students."primary" AND classroom_students.left_at IS NULL
        JOIN classrooms ON classrooms.id = classroom_students.classroom_id
          AND classrooms.status = 'active' AND classrooms.school_year = :year
        JOIN users ON users.id = exercise_sessions.student_id AND users.anonymized_at IS NULL
        WHERE classrooms.school_id IN (:ids)
        GROUP BY classrooms.school_id
      SQL

      ASSIGNMENTS = <<~SQL.squish.freeze
        SELECT classrooms.school_id, MAX(classroom_assignments.assigned_at)
        FROM classroom_assignments JOIN classrooms ON classrooms.id = classroom_assignments.classroom_id
        WHERE classrooms.school_id IN (:ids)
        GROUP BY classrooms.school_id
      SQL

      # → { school_id => Entities::Crm::SchoolUsage }, une entrée par école demandée (zéros si rien n'est rattaché)
      def call(school_ids:, today: Date.current)
        ids = Array(school_ids).uniq
        return {} if ids.empty?

        binds = { ids:, year: Entities::Classroom::SchoolYear.current(today),
                  since: (today - Entities::Crm::Stage::ACTIVE_WINDOW + 1).in_time_zone }
        accounts = rows(ACCOUNTS, binds).to_h { |id, count, first| [ id, [ count, first ] ] }
        sessions = rows(SESSIONS, binds).to_h { |id, last, active| [ id, [ last, active ] ] }
        assigned = rows(ASSIGNMENTS, binds).to_h

        ids.to_h do |id|
          count, first = accounts.fetch(id, [ 0, nil ])
          last_session, active = sessions.fetch(id, [ nil, 0 ])
          [ id, Entities::Crm::SchoolUsage.new(school_id: id, accounts_count: count, active_students_count: active,
                                               last_activity_on: date([ last_session, assigned[id] ].compact.max),
                                               first_attached_on: date(first)) ]
        end
      end

      private

      def rows(sql, binds)
        Orm::School.connection.select_all(Orm::School.sanitize_sql_array([ sql, binds ])).cast_values
      end

      def date(time) = time&.in_time_zone&.to_date
    end
  end
end
