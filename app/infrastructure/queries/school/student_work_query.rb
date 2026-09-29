# 🔌 INFRA · Queries::School::StudentWorkQuery
# Rôle : « Travail des élèves » de la direction (DS-07 à DS-10) : chiffres de chaque classe de l'année, puis de ses élèves
# ADR  : 0006, 0062, 0065 · UDR : 0052 · un nombre fixe de requêtes groupées, quel que soit le volume
module Queries
  module School
    class StudentWorkQuery
      MIN_STUDENTS_FOR_AVERAGE = 5
      # submission_rate, average_percent : nil → « — »
      ClassroomRow = Data.define(:public_id, :name, :level_name, :students_count, :assignments_count,
                                 :submission_rate, :average_percent)
      StudentRow = Data.define(:display_name, :submitted_count, :average_percent)
      Overview = Data.define(:school_name, :school_year, :classrooms)
      Detail = Data.define(:classroom, :students)

      CLASSROOM_COLUMNS = %w[classrooms.id classrooms.public_id classrooms.name levels.name].freeze
      # Un élève présent : adhésion non quittée, compte non anonymisé (ADR-0065 §4).
      PRESENT = "JOIN classroom_students ON classroom_students.student_id = users.id AND classroom_students.left_at IS NULL"
      # Une session rendue : terminée, standard, rattachée à un devoir de la classe, par un élève présent de cette classe.
      SUBMITTED = "JOIN classroom_assignments ON classroom_assignments.id = exercise_sessions.classroom_assignment_id " \
                  "JOIN classroom_students ON classroom_students.classroom_id = classroom_assignments.classroom_id " \
                  "AND classroom_students.student_id = exercise_sessions.student_id AND classroom_students.left_at IS NULL " \
                  "JOIN users ON users.id = exercise_sessions.student_id AND users.anonymized_at IS NULL"
      # Par clé (classe ou élève) : devoirs rendus distincts, élèves ayant rendu, somme et nombre des scores.
      TOTALS = [ "COUNT(DISTINCT (exercise_sessions.student_id, exercise_sessions.classroom_assignment_id))",
                 "COUNT(DISTINCT exercise_sessions.student_id)", "SUM(exercise_sessions.score_percent)", "COUNT(*)" ].freeze
      Totals = Data.define(:submitted, :students, :score_sum, :sessions) do
        def self.none = new(submitted: 0, students: 0, score_sum: 0, sessions: 0)

        def average
          (score_sum.to_f / sessions).round unless sessions.zero?
        end
      end

      # → Overview
      def classrooms(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        rows = active_classrooms(school_id, school_year).order("levels.position", "classrooms.name").pluck(*CLASSROOM_COLUMNS)
        ids = rows.map(&:first)
        students = present_students.where(classroom_students: { classroom_id: ids }).group("classroom_students.classroom_id").count
        assignments = Orm::ClassroomAssignment.where(classroom_id: ids).group(:classroom_id).count
        totals = totals_by("classroom_assignments.classroom_id", classroom_assignments: { classroom_id: ids })

        Overview.new(school_name: Orm::School.where(id: school_id).pick(:name), school_year:,
                     classrooms: rows.map { |row| classroom_row(row, students.fetch(row.first, 0), assignments.fetch(row.first, 0), totals) })
      end

      # → Detail | nil : nil pour une classe inconnue, archivée, d'une autre année ou d'un autre établissement.
      def classroom(school_id:, public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        row = active_classrooms(school_id, school_year).where(public_id: public_id.to_s).pick(*CLASSROOM_COLUMNS)
        return if row.nil?

        students = present_students.where(classroom_students: { classroom_id: row.first })
                                   .order(:last_name, :first_name, :id).pluck(:id, :first_name, :last_name)
        assignments_count = Orm::ClassroomAssignment.where(classroom_id: row.first).count
        totals = totals_by("exercise_sessions.student_id", classroom_assignments: { classroom_id: row.first })

        Detail.new(classroom: classroom_row(row, students.size, assignments_count, { row.first => sum(totals.values) }),
                   students: students.map { |id, first_name, last_name| student_row("#{first_name} #{last_name}", totals[id]) })
      end

      private

      def active_classrooms(school_id, school_year)
        Orm::Classroom.joins(:level).where(school_id:, school_year:, status: "active")
      end

      def present_students = Orm::User.joins(PRESENT).where(anonymized_at: nil)

      # { clé => Totals } en une requête ; les sessions de remédiation (ADR-0043) ne comptent pas.
      def totals_by(key, **scope)
        Orm::ExerciseSession.joins(SUBMITTED).where(status: "completed", kind: "standard", **scope).group(key)
                            .pluck(Arel.sql(key), *TOTALS.map { Arel.sql(it) })
                            .to_h { |id, *values| [ id, Totals.new(*values) ] }
      end

      def sum(totals) = Totals.new(**Totals.members.to_h { |member| [ member, totals.sum(&member) ] })

      def classroom_row(row, students_count, assignments_count, totals)
        id, public_id, name, level_name = row
        total = totals.fetch(id, Totals.none)
        given = students_count * assignments_count
        ClassroomRow.new(public_id:, name:, level_name:, students_count:, assignments_count:,
                         submission_rate: ((total.submitted * 100.0 / given).round unless given.zero?),
                         average_percent: (total.average if total.students >= MIN_STUDENTS_FOR_AVERAGE))
      end

      def student_row(display_name, totals)
        total = totals || Totals.none
        StudentRow.new(display_name:, submitted_count: total.submitted, average_percent: total.average)
      end
    end
  end
end
