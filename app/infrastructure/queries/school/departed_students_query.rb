# 🔌 INFRA · Queries::School::DepartedStudentsQuery
# Rôle : « Anciens élèves » de la direction : les élèves passés par ses classes, absents de ses classes de l'année, et leurs
#        résultats obtenus chez elle (devoirs rendus de ses classes, médailles)
# ADR  : 0036, 0040, 0041, 0065, 0072 · UDR : 0052 · deux requêtes ; rendu : standard ou remédiation ; anonymisé exclu (ADR-0036 §4)
module Queries
  module School
    class DepartedStudentsQuery
      Overview = Data.define(:school_name, :students, :truncated)
      # La dernière classe de l'élève dans l'établissement ; submitted_count : devoirs rendus distincts ;
      # medals : { :bronze => n … } gagnées dans les classes de l'établissement, par exercice (UDR médailles), vide sans médaille.
      Row = Data.define(:display_name, :classroom_name, :level_name, :school_year, :submitted_count, :medals)

      LIMIT = 200
      FULL_NAME = "users.first_name || ' ' || users.last_name".freeze
      # Les adhésions de l'établissement seul, lues une fois et groupées par élève (chantier ecrans-direction-lents) : sa
      # dernière classe, quittée ou non (la plus récemment rejointe, la plus haute à égalité), et aucune adhésion présente.
      # Présent : adhésion non quittée d'une classe active de l'année, comme « Travail des élèves » (StudentWorkQuery).
      # Sans adhésion ici, l'élève n'est jamais passé par l'établissement.
      PASSED = <<~SQL.squish.freeze
        JOIN (SELECT classroom_students.student_id, (array_agg(classroom_students.classroom_id
        ORDER BY classroom_students.joined_at DESC, classroom_students.id DESC))[1] AS classroom_id
        FROM classroom_students JOIN classrooms ON classrooms.id = classroom_students.classroom_id
        WHERE classrooms.school_id = :school_id GROUP BY classroom_students.student_id
        HAVING NOT bool_or(classroom_students.left_at IS NULL AND classrooms.status = 'active'
        AND classrooms.school_year = :school_year)) passed ON passed.student_id = users.id
        JOIN classrooms last_classroom ON last_classroom.id = passed.classroom_id JOIN levels ON levels.id = last_classroom.level_id
      SQL
      COLUMNS = [ "users.id", Arel.sql(FULL_NAME), "last_classroom.name", "levels.name", "last_classroom.school_year" ].freeze
      TOTALS = [ :student_id, Arel.sql("COUNT(DISTINCT exercise_sessions.classroom_assignment_id)") ].freeze

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
        ids = rows.first(@limit).map(&:first)
        totals = totals(school_id, ids)
        medals = Queries::Assessment::Medals.by_student_in_school(school_id:, student_ids: ids)

        Overview.new(school_name: Orm::School.where(id: school_id).pick(:name), truncated: rows.size > @limit,
                     students: rows.first(@limit).map { |id, *row| row_for(row, totals[id], medals.fetch(id, {})) })
      end

      private

      def departed(school_id, school_year)
        Orm::User.where(role: "student", anonymized_at: nil)
                 .joins(ActiveRecord::Base.sanitize_sql([ PASSED, { school_id:, school_year: } ]))
      end

      # Les devoirs rendus dans les classes de l'établissement : sessions terminées d'une de ses assignations, remédiation
      # comprise (ADR-0072 §4.4, complément ter), comme « Travail des élèves ».
      def totals(school_id, student_ids)
        Orm::ExerciseSession.joins(classroom_assignment: :classroom)
                            .where(student_id: student_ids, status: "completed", classrooms: { school_id: })
                            .group(:student_id).pluck(*TOTALS)
                            .to_h
      end

      def row_for(row, submitted_count, medals)
        display_name, classroom_name, level_name, school_year = row
        Row.new(display_name:, classroom_name:, level_name:, school_year:, submitted_count: submitted_count || 0,
                medals: Entities::Assessment::Grading::BADGE_ORDER.filter_map { |level| [ level, medals[level] ] if medals[level] }.to_h)
      end
    end
  end
end
