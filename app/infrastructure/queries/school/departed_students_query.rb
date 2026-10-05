# 🔌 INFRA · Queries::School::DepartedStudentsQuery
# Rôle : « Anciens élèves » de la direction : les élèves passés par ses classes, absents de ses classes de l'année, et leurs
#        résultats obtenus chez elle (devoirs rendus de ses classes, score moyen)
# ADR  : 0036, 0040, 0041, 0065, 0072 · UDR : 0052 · deux requêtes ; rendu : standard ou remédiation ; anonymisé exclu (ADR-0036 §4)
module Queries
  module School
    class DepartedStudentsQuery
      Overview = Data.define(:school_name, :students, :truncated)
      # La dernière classe de l'élève dans l'établissement ; submitted_count : devoirs rendus distincts ; average_percent : nil → « — ».
      Row = Data.define(:display_name, :classroom_name, :level_name, :school_year, :submitted_count, :average_percent)

      LIMIT = 200
      FULL_NAME = "users.first_name || ' ' || users.last_name".freeze
      # Sa dernière classe dans l'établissement, quittée ou non ; sans elle, l'élève n'est jamais passé par l'établissement.
      LAST_CLASSROOM = <<~SQL.squish.freeze
        JOIN LATERAL (SELECT classrooms.name, levels.name AS level_name, classrooms.school_year FROM classroom_students
        JOIN classrooms ON classrooms.id = classroom_students.classroom_id JOIN levels ON levels.id = classrooms.level_id
        WHERE classroom_students.student_id = users.id AND classrooms.school_id = :school_id
        ORDER BY classroom_students.joined_at DESC, classroom_students.id DESC LIMIT 1) last_classroom ON true
      SQL
      # Présent : adhésion non quittée d'une classe active de l'année, comme « Travail des élèves » (StudentWorkQuery).
      NOT_PRESENT = <<~SQL.squish.freeze
        NOT EXISTS (SELECT 1 FROM classroom_students JOIN classrooms ON classrooms.id = classroom_students.classroom_id
        WHERE classroom_students.student_id = users.id AND classroom_students.left_at IS NULL
        AND classrooms.school_id = :school_id AND classrooms.status = 'active' AND classrooms.school_year = :school_year)
      SQL
      COLUMNS = [ "users.id", Arel.sql(FULL_NAME), "last_classroom.name", "last_classroom.level_name", "last_classroom.school_year" ].freeze
      TOTALS = [ :student_id, Arel.sql("COUNT(DISTINCT exercise_sessions.classroom_assignment_id)"),
                 Arel.sql("SUM(exercise_sessions.score_percent)"), Arel.sql("COUNT(*)") ].freeze

      def initialize(limit: LIMIT)
        @limit = limit
      end

      # school_id vient toujours du compte de la direction, jamais de l'adresse ; search : un nom, sans casse ni accents.
      # → Overview ; les départs les plus récents d'abord (année de la dernière classe), puis par nom.
      def call(school_id:, search: "", today: Date.current)
        school_year = Entities::Classroom::SchoolYear.current(today)
        rows = Queries::Shared::TextSearch.apply(departed(school_id, school_year), search, columns: [ FULL_NAME ])
                                          .order("last_classroom.school_year DESC", "users.last_name", "users.first_name", "users.id")
                                          .limit(@limit + 1).pluck(*COLUMNS)
        totals = totals(school_id, rows.first(@limit).map(&:first))

        Overview.new(school_name: Orm::School.where(id: school_id).pick(:name), truncated: rows.size > @limit,
                     students: rows.first(@limit).map { |id, *row| row_for(row, totals[id]) })
      end

      private

      def departed(school_id, school_year)
        Orm::User.where(role: "student", anonymized_at: nil)
                 .joins(ActiveRecord::Base.sanitize_sql([ LAST_CLASSROOM, { school_id: } ]))
                 .where(NOT_PRESENT, school_id:, school_year:)
      end

      # Les devoirs rendus dans les classes de l'établissement : sessions terminées d'une de ses assignations, remédiation
      # comprise (ADR-0072 §4.4, complément ter), comme « Travail des élèves ».
      def totals(school_id, student_ids)
        Orm::ExerciseSession.joins(classroom_assignment: :classroom)
                            .where(student_id: student_ids, status: "completed", classrooms: { school_id: })
                            .group(:student_id).pluck(*TOTALS)
                            .to_h { |id, submitted, score_sum, sessions| [ id, [ submitted, (score_sum.to_f / sessions).round ] ] }
      end

      def row_for(row, totals)
        display_name, classroom_name, level_name, school_year = row
        submitted_count, average_percent = totals || [ 0, nil ]
        Row.new(display_name:, classroom_name:, level_name:, school_year:, submitted_count:, average_percent:)
      end
    end
  end
end
