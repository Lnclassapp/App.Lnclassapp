# 🔌 INFRA · Queries::Crm::PedagogyReportQuery
# Rôle : les chiffres pédagogiques d'une école sur 30 jours (élèves actifs, devoirs, taux de rendu, réussite par matière, 5 lacunes) ; agrégats seulement
# ADR  : XXXX (modèles de langage, « Données envoyées » : aucun nom d'élève) · lecture seule (CQRS) ; six requêtes, quel que soit le nombre d'élèves
module Queries
  module Crm
    class PedagogyReportQuery
      GAPS = 5

      # Les élèves de l'école : classe principale, active, de l'année, compte non anonymisé (comme SchoolUsageQuery).
      STUDENTS = <<~SQL.squish.freeze
        FROM exercise_sessions
        JOIN classroom_students ON classroom_students.student_id = exercise_sessions.student_id
          AND classroom_students."primary" AND classroom_students.left_at IS NULL
        JOIN classrooms ON classrooms.id = classroom_students.classroom_id
          AND classrooms.status = 'active' AND classrooms.school_year = :year
        JOIN users ON users.id = exercise_sessions.student_id AND users.anonymized_at IS NULL
      SQL

      ACTIVE = "SELECT COUNT(DISTINCT exercise_sessions.student_id) #{STUDENTS} " \
               "WHERE classrooms.school_id = :id AND exercise_sessions.started_at >= :since".freeze

      SUBJECTS = <<~SQL.squish.freeze
        SELECT materials.name, materials.category, COUNT(*), SUM(exercise_sessions.score_percent) #{STUDENTS}
        JOIN exercises ON exercises.id = exercise_sessions.exercise_id
        JOIN courses ON courses.id = exercises.course_id
        JOIN materials ON materials.id = courses.material_id
        WHERE classrooms.school_id = :id AND exercise_sessions.started_at >= :since AND exercise_sessions.status = 'completed'
        GROUP BY materials.id, materials.name, materials.category
        ORDER BY materials.name, materials.id
      SQL

      # Devoirs donnés sur la période (non archivés) et, pour chacun, les élèves présents de sa classe qui devaient le rendre.
      ASSIGNMENTS = <<~SQL.squish.freeze
        SELECT COUNT(*), COALESCE(SUM((SELECT COUNT(*) FROM classroom_students
          JOIN users ON users.id = classroom_students.student_id AND users.anonymized_at IS NULL
          WHERE classroom_students.classroom_id = classroom_assignments.classroom_id AND classroom_students.left_at IS NULL)), 0)
        FROM classroom_assignments
        JOIN classrooms ON classrooms.id = classroom_assignments.classroom_id
          AND classrooms.status = 'active' AND classrooms.school_year = :year
        WHERE classrooms.school_id = :id AND classroom_assignments.status = 'active' AND classroom_assignments.assigned_at >= :since
      SQL

      # Rendus : un élève présent avec au moins une session terminée sur le devoir, compté une fois par devoir.
      HANDED_IN = <<~SQL.squish.freeze
        SELECT COUNT(*) FROM (
          SELECT DISTINCT exercise_sessions.classroom_assignment_id, exercise_sessions.student_id
          FROM exercise_sessions
          JOIN classroom_assignments ON classroom_assignments.id = exercise_sessions.classroom_assignment_id
          JOIN classrooms ON classrooms.id = classroom_assignments.classroom_id
            AND classrooms.status = 'active' AND classrooms.school_year = :year
          JOIN classroom_students ON classroom_students.classroom_id = classroom_assignments.classroom_id
            AND classroom_students.student_id = exercise_sessions.student_id AND classroom_students.left_at IS NULL
          JOIN users ON users.id = exercise_sessions.student_id AND users.anonymized_at IS NULL
          WHERE classrooms.school_id = :id AND classroom_assignments.status = 'active' AND classroom_assignments.assigned_at >= :since
            AND exercise_sessions.status = 'completed'
        ) handed
      SQL

      # → Entities::Crm::PedagogyReportPrompt | nil (école inconnue). Une école sans activité rend des zéros.
      def call(public_id: nil, school_id: nil, today: Date.current)
        id = Orm::School.where(**{ public_id:, id: school_id }.compact).pick(:id)
        return nil if id.nil?

        binds = { id:, year: Entities::Classroom::SchoolYear.current(today),
                  since: (today - (Entities::Crm::PedagogyReportPrompt::WINDOW_DAYS - 1)).in_time_zone }
        subjects = subject_rows(binds)
        assignments, expected = rows(ASSIGNMENTS, binds).first
        Entities::Crm::PedagogyReportPrompt.new(
          school_id: id, active_students_count: rows(ACTIVE, binds).first.first, assignments_count: assignments,
          submission_rate: submission_rate(rows(HANDED_IN, binds).first.first, expected), average_percent: average(subjects),
          subjects: subjects.map do |name, category, count, sum|
            { name:, category:, average_percent: (sum.to_f / count).round, sessions_count: count }
          end,
          gaps: gaps(id, binds.fetch(:year))
        )
      end

      private

      def rows(sql, binds) = Orm::School.connection.select_all(Orm::School.sanitize_sql_array([ sql, binds ])).cast_values.map { Array(it) }

      def subject_rows(binds) = rows(SUBJECTS, binds)

      def average(subjects)
        count = subjects.sum { it[2] }
        (subjects.sum { it[3].to_i }.to_f / count).round if count.positive?
      end

      def submission_rate(handed, expected)
        (handed * 100.0 / expected).round.clamp(0, 100) if expected.positive?
      end

      # Fiches à revoir (lacunes en attente) des élèves de l'école, par nombre d'élèves décroissant : le titre de la fiche et du cours, jamais un élève.
      def gaps(school_id, year)
        Orm::KnowledgeGap.joins(essential: :course).where(status: "pending", essentials: { status: "published" }, courses: { status: "published" })
                         .joins("JOIN classroom_students ON classroom_students.student_id = knowledge_gaps.student_id " \
                                "AND classroom_students.\"primary\" AND classroom_students.left_at IS NULL")
                         .joins("JOIN classrooms ON classrooms.id = classroom_students.classroom_id AND classrooms.status = 'active'")
                         .joins("JOIN users ON users.id = knowledge_gaps.student_id AND users.anonymized_at IS NULL")
                         .where(classrooms: { school_id:, school_year: year })
                         .group("essentials.id", "essentials.name", "courses.name")
                         .order(Arel.sql("COUNT(DISTINCT knowledge_gaps.student_id) DESC"), "essentials.name", "essentials.id")
                         .limit(GAPS)
                         .pluck("essentials.name", "courses.name", Arel.sql("COUNT(DISTINCT knowledge_gaps.student_id)"))
                         .map { |name, course_name, students_count| { name:, course_name:, students_count: } }
      end
    end
  end
end
