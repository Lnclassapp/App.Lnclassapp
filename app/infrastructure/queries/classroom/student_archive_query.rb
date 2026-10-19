# 🔌 INFRA · Queries::Classroom::StudentArchiveQuery
# Rôle : « Mon historique » de l'élève, même sans classe active : ses classes, quittées ou non, et ses exercices terminés
# ADR  : 0036, 0040, 0041, 0095 · UDR : 0057, 0090, 0103 · trois requêtes, quel que soit le volume ; aucun filtre de niveau : c'est son archive
module Queries
  module Classroom
    class StudentArchiveQuery
      # completed_count : le vrai total des exercices terminés, sans la limite de la liste (UDR-0090 §3.1).
      Archive = Data.define(:classrooms, :results, :completed_count)
      # UDR-0103 §3.1 : la période de l'adhésion ; current : non quittée et classe active (la classe d'aujourd'hui).
      ClassroomRow = Data.define(:name, :level_name, :school_name, :school_year, :joined_at, :left_at, :current)
      # material_slug : slug figé de la matière, qui choisit son illustration (UDR-0069 §3.3, UDR-0090 §3.2).
      ResultRow = Data.define(:exercise_title, :material_name, :material_slug, :material_category, :score_percent, :completed_at)

      # Les plus récents : la page reste légère après plusieurs années d'exercices.
      RESULTS_LIMIT = 200
      CLASSROOM_COLUMNS = [ "classrooms.name", "levels.name", "schools.name", "classrooms.school_year", :joined_at, :left_at,
                            "classrooms.status" ].freeze
      RESULT_COLUMNS = [ "exercises.title", "materials.name", "materials.slug", "materials.category", :score_percent,
                         :completed_at ].freeze

      def initialize(results_limit: RESULTS_LIMIT)
        @results_limit = results_limit
      end

      # → Archive ; ses classes de la plus récemment rejointe à la plus ancienne, ses exercices du plus récent au plus ancien.
      def call(student_id:)
        Archive.new(classrooms: classrooms(student_id), results: results(student_id),
                    completed_count: completed(student_id).count)
      end

      # Une adhésion, même quittée, ou un exercice terminé : l'élève a une archive à consulter.
      def any?(student_id:)
        Orm::ClassroomStudent.exists?(student_id:) || completed(student_id).exists?
      end

      private

      def classrooms(student_id)
        Orm::ClassroomStudent.joins(classroom: %i[level school]).where(student_id:)
                             .order(joined_at: :desc, id: :desc).pluck(*CLASSROOM_COLUMNS)
                             .map { |*values, left_at, status| ClassroomRow.new(*values, left_at, left_at.nil? && status == "active") }
      end

      def results(student_id)
        completed(student_id).joins(exercise: { essential: { course: :material } })
                             .order(completed_at: :desc, id: :desc).limit(@results_limit).pluck(*RESULT_COLUMNS)
                             .map { ResultRow.new(*it) }
      end

      def completed(student_id) = Orm::ExerciseSession.where(student_id:, status: "completed")
    end
  end
end
