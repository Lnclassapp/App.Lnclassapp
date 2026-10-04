# 🔌 INFRA · Queries::School::StudentWorkQuery
# Rôle : travail des élèves de la direction (DS-07 à DS-10) : chiffres de chaque classe de l'année, d'un niveau, puis des élèves
# ADR  : 0006, 0062, 0065 · UDR : 0052, 0072 · un nombre fixe de requêtes groupées, quel que soit le volume
module Queries
  module School
    class StudentWorkQuery
      MIN_STUDENTS_FOR_AVERAGE = 5
      # submission_rate, average_percent : nil → « — » ; submitted_count : devoirs rendus (élève, devoir) distincts, la
      # somme qui fait le taux d'un niveau (UDR-0072 §3.2).
      ClassroomRow = Data.define(:public_id, :name, :level_name, :level_slug, :students_count, :assignments_count,
                                 :submitted_count, :submission_rate, :average_percent)
      StudentRow = Data.define(:display_name, :submitted_count, :average_percent)
      # students_count : élèves présents distincts de l'établissement ; un élève de deux classes compte une fois (UDR-0072).
      Overview = Data.define(:school_name, :school_year, :students_count, :classrooms)
      Detail = Data.define(:classroom, :students)
      # students_count : élèves présents distincts du niveau, même règle (phase 5, O1).
      LevelOverview = Data.define(:level_name, :level_slug, :students_count, :classrooms)

      CLASSROOM_COLUMNS = %w[classrooms.id classrooms.public_id classrooms.name levels.name levels.slug].freeze
      # Un élève présent : adhésion non quittée, compte non anonymisé (ADR-0065 §4).
      PRESENT = "JOIN classroom_students ON classroom_students.student_id = users.id AND classroom_students.left_at IS NULL"
      # Un devoir rendu : au moins une session terminée, standard, rattachée à un devoir de la classe. Une ligne par
      # (classe, devoir, élève), lue sur l'index partiel des sessions rendues (index_exercise_sessions_handed_in).
      HANDED_IN = "JOIN exercise_sessions ON exercise_sessions.classroom_assignment_id = classroom_assignments.id " \
                  "AND exercise_sessions.status = 'completed' AND exercise_sessions.kind = 'standard'"
      HANDED_IN_COLUMNS = [ "classroom_assignments.classroom_id", "exercise_sessions.student_id",
                            "SUM(exercise_sessions.score_percent) AS score_sum", "COUNT(*) AS sessions" ].freeze
      # Par clé (classe ou élève) : devoirs rendus distincts, élèves ayant rendu, somme et nombre des scores.
      TOTALS = [ "COUNT(*)", "COUNT(DISTINCT handed.student_id)", "SUM(handed.score_sum)::bigint", "SUM(handed.sessions)::bigint" ].freeze
      Totals = Data.define(:submitted, :students, :score_sum, :sessions) do
        def self.none = new(submitted: 0, students: 0, score_sum: 0, sessions: 0)

        def average
          (score_sum.to_f / sessions).round unless sessions.zero?
        end
      end

      # → Overview
      def classrooms(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        rows = active_classrooms(school_id, school_year).order("levels.position", "classrooms.name").pluck(*CLASSROOM_COLUMNS)
        students_count, classrooms = classroom_rows(rows)

        Overview.new(school_name: Orm::School.where(id: school_id).pick(:name), school_year:, students_count:, classrooms:)
      end

      # La page d'un niveau (UDR-0072 §3.8) : ses classes actives de l'année dans cet établissement, par nom. → LevelOverview
      # | nil : nil pour un slug inconnu ou un niveau sans classe active de l'établissement cette année (404).
      def level(school_id:, slug:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        rows = active_classrooms(school_id, school_year).where(levels: { slug: slug.to_s }).order("classrooms.name")
                                                        .pluck(*CLASSROOM_COLUMNS)
        return if rows.empty?

        students_count, classrooms = classroom_rows(rows)
        LevelOverview.new(level_name: rows.first[3], level_slug: rows.first[4], students_count:, classrooms:)
      end

      # → Detail | nil : nil pour une classe inconnue, archivée, d'une autre année ou d'un autre établissement.
      def classroom(school_id:, public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        row = active_classrooms(school_id, school_year).where(public_id: public_id.to_s).pick(*CLASSROOM_COLUMNS)
        return if row.nil?

        students = present_students.where(classroom_students: { classroom_id: row.first })
                                   .order(:last_name, :first_name, :id).pluck(:id, :first_name, :last_name)
        assignments_count = Orm::ClassroomAssignment.where(classroom_id: row.first).count
        totals = totals_by("classroom_students.student_id", row.first)

        Detail.new(classroom: classroom_row(row, students.size, assignments_count, { row.first => sum(totals.values) }),
                   students: students.map { |id, first_name, last_name| student_row("#{first_name} #{last_name}", totals[id]) })
      end

      private

      # Les lignes de classes lues, avec leurs effectifs, devoirs et totaux, et le nombre d'élèves distincts de ces classes :
      # trois requêtes, quel que soit le nombre. → [élèves distincts, [ClassroomRow]]
      def classroom_rows(rows)
        ids = rows.map(&:first)
        students = present_counts(ids)
        assignments = Orm::ClassroomAssignment.where(classroom_id: ids).group(:classroom_id).count
        totals = totals_by("classroom_students.classroom_id", ids)
        [ students.fetch(nil, 0), rows.map { |row| classroom_row(row, students.fetch(row.first, 0), assignments.fetch(row.first, 0), totals) } ]
      end

      # { classroom_id => élèves présents, nil => élèves présents distincts de toutes ces classes } en une lecture : la ligne
      # du groupe vide (`()`) compte chaque élève une fois, même présent dans deux classes (budget ADR-0067). Sans classe,
      # Rails ne lit rien : le total vaut alors 0.
      def present_counts(ids)
        present_students.where(classroom_students: { classroom_id: ids })
                        .group(Arel.sql("GROUPING SETS ((classroom_students.classroom_id), ())"))
                        .pluck(Arel.sql("classroom_students.classroom_id"), Arel.sql("COUNT(DISTINCT users.id)")).to_h
      end

      def active_classrooms(school_id, school_year)
        Orm::Classroom.joins(:level).where(school_id:, school_year:, status: "active")
      end

      def present_students = Orm::User.joins(PRESENT).where(anonymized_at: nil)

      # { clé => Totals } en une requête ; les sessions de remédiation (ADR-0043) ne comptent pas. Une session rendue compte
      # si son élève est présent dans la classe du devoir : on part des adhésions présentes des classes, jamais des sessions.
      def totals_by(key, classroom_ids)
        handed = Orm::ClassroomAssignment.joins(HANDED_IN).where(classroom_id: classroom_ids)
                                         .group("classroom_assignments.classroom_id", "exercise_sessions.classroom_assignment_id",
                                                "exercise_sessions.student_id")
                                         .select(*HANDED_IN_COLUMNS)
        Orm::ClassroomStudent.joins(:student).where(classroom_id: classroom_ids, left_at: nil, users: { anonymized_at: nil })
                             .joins("JOIN (#{handed.to_sql}) handed ON handed.classroom_id = classroom_students.classroom_id " \
                                    "AND handed.student_id = classroom_students.student_id")
                             .group(key).pluck(Arel.sql(key), *TOTALS.map { Arel.sql(it) })
                             .to_h { |id, *values| [ id, Totals.new(*values) ] }
      end

      def sum(totals) = Totals.new(**Totals.members.to_h { |member| [ member, totals.sum(&member) ] })

      def classroom_row(row, students_count, assignments_count, totals)
        id, public_id, name, level_name, level_slug = row
        total = totals.fetch(id, Totals.none)
        given = students_count * assignments_count
        ClassroomRow.new(public_id:, name:, level_name:, level_slug:, students_count:, assignments_count:, submitted_count: total.submitted,
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
