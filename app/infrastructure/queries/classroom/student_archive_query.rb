# 🔌 INFRA · Queries::Classroom::StudentArchiveQuery
# Rôle : « Mon historique » de l'élève, même sans classe active : ses classes, quittées ou non, et ses exercices terminés
# ADR  : 0036, 0040, 0041 · UDR : 0057 · deux requêtes, quel que soit le volume ; aucun filtre de niveau : c'est son archive
module Queries
  module Classroom
    class StudentArchiveQuery
      Archive = Data.define(:classrooms, :results)
      ClassroomRow = Data.define(:name, :level_name, :school_name, :school_year)
      ResultRow = Data.define(:exercise_title, :material_name, :material_category, :score_percent, :completed_at)

      # Les plus récents : la page reste légère après plusieurs années d'exercices.
      RESULTS_LIMIT = 200
      CLASSROOM_COLUMNS = [ "classrooms.name", "levels.name", "schools.name", "classrooms.school_year" ].freeze
      RESULT_COLUMNS = [ "exercises.title", "materials.name", "materials.category", :score_percent, :completed_at ].freeze

      def initialize(results_limit: RESULTS_LIMIT)
        @results_limit = results_limit
      end

      # → Archive ; ses classes de la plus récemment rejointe à la plus ancienne, ses exercices du plus récent au plus ancien.
      def call(student_id:)
        Archive.new(classrooms: classrooms(student_id), results: results(student_id))
      end

      # Une adhésion, même quittée, ou un exercice terminé : l'élève a une archive à consulter.
      def any?(student_id:)
        Orm::ClassroomStudent.exists?(student_id:) || completed(student_id).exists?
      end

      private

      def classrooms(student_id)
        Orm::ClassroomStudent.joins(classroom: %i[level school]).where(student_id:)
                             .order(joined_at: :desc, id: :desc).pluck(*CLASSROOM_COLUMNS)
                             .map { |name, level_name, school_name, school_year| ClassroomRow.new(name:, level_name:, school_name:, school_year:) }
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
