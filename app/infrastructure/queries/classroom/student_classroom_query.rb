# 🔌 INFRA · Queries::Classroom::StudentClassroomQuery
# Rôle : « Ma classe » (CL-22) : la classe principale active, les cours de ses exercices assignés, les exercices à faire et traités
# ADR  : 0026, 0035, 0048, 0067, 0072 · UDR : 0011, 0076 §3.2 · le code de la classe vient de ClassroomHeaderQuery, sous ReadClassroomPolicy
module Queries
  module Classroom
    class StudentClassroomQuery
      # Jamais de liste nominative ni le travail d'un autre élève (UDR-0011). assigned_exercises : les ExerciseRow de
      # StudentHomeQuery que l'élève n'a pas encore terminés ; treated_exercises : ce qu'il a terminé, de son niveau.
      Row = Data.define(:public_id, :classroom_name, :level_name, :series_name, :school_name, :school_year,
                        :courses, :assigned_exercises, :treated_exercises)
      # assigned_count : les exercices du cours assignés à la classe (ADR-0072 : un cours ne s'assigne plus).
      CourseRow = Data.define(:slug, :name, :material_name, :material_slug, :material_category, :assigned_count)
      # best_score_percent : le meilleur score de l'élève ; last_session_public_id : sa dernière session terminée.
      TreatedRow = Data.define(:exercise_public_id, :title, :material_name, :material_category, :best_score_percent,
                               :last_session_public_id, :last_completed_at)

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "series.name", "schools.name",
                  "classrooms.school_year" ].freeze
      COURSE_COLUMNS = [ "courses.slug", "courses.name", "materials.name", "materials.slug", "materials.category",
                         Arel.sql("COUNT(DISTINCT exercises.id)") ].freeze
      # DISTINCT ON garde, par exercice, la dernière session terminée ; la fenêtre lit le meilleur score avant ce tri.
      TREATED_COLUMNS = [ Arel.sql("DISTINCT ON (exercise_sessions.exercise_id) exercises.public_id"), "exercises.title",
                          "materials.name", "materials.category",
                          Arel.sql("MAX(exercise_sessions.score_percent) OVER (PARTITION BY exercise_sessions.exercise_id)"),
                          "exercise_sessions.public_id", "exercise_sessions.completed_at" ].freeze

      # → Row | nil (aucune classe principale active : l'élève n'a pas de classe à ouvrir)
      def call(student_id:)
        primary = Orm::ClassroomStudent.where(student_id:, primary: true, left_at: nil).select(:classroom_id)
        id, public_id, classroom_name, level_name, series_name, school_name, school_year =
          Orm::Classroom.joins(:level, :school).left_joins(:series).where(id: primary, status: "active").pick(*COLUMNS)
        return if id.nil?

        Row.new(public_id:, classroom_name:, level_name:, series_name:, school_name:, school_year:,
                courses: courses(id, student_id), assigned_exercises: assigned_exercises(id, student_id),
                treated_exercises: treated_exercises(student_id))
      end

      private

      # UDR-0013, amendement du 2026-10-01 : rien d'un autre niveau que celui de l'élève.
      def own_level(student_id)
        @own_level ||= Queries::Catalog::AudienceFilter.courses(Queries::Catalog::StudentAudienceQuery.new.call(student_id:))
      end

      # Les cours publiés d'un exercice publié assigné à la classe ; le plus récemment assigné d'abord.
      def courses(classroom_id, student_id)
        Orm::Course.joins(:material, essentials: :exercises)
                   .joins("INNER JOIN classroom_assignments ON classroom_assignments.assignable_type = 'Exercise' " \
                          "AND classroom_assignments.assignable_id = exercises.id")
                   .where(classroom_assignments: { classroom_id:, status: "active" }, status: "published",
                          essentials: { status: "published" }, exercises: { status: "published" })
                   .merge(own_level(student_id))
                   .group("courses.id", "materials.id")
                   .order(Arel.sql("MAX(classroom_assignments.assigned_at) DESC"), "courses.id")
                   .pluck(*COURSE_COLUMNS)
                   .map { |slug, name, material_name, material_slug, material_category, assigned_count| CourseRow.new(slug:, name:, material_name:, material_slug:, material_category:, assigned_count:) }
      end

      # Chaque exercice n'est dit qu'une fois sur la page (UDR-0057 R6) : un exercice terminé passe dans « traités ».
      def assigned_exercises(classroom_id, student_id)
        StudentHomeQuery.new.assigned_exercises(classroom_id:, student_id:).select { it.completed_count.zero? }
      end

      def treated_exercises(student_id)
        Orm::ExerciseSession.joins(exercise: { essential: { course: :material } })
                            .where(student_id:, status: "completed").merge(own_level(student_id))
                            .order("exercise_sessions.exercise_id", completed_at: :desc, id: :desc)
                            .pluck(*TREATED_COLUMNS)
                            .map { |values| TreatedRow.new(*values) }
                            .sort_by { -it.last_completed_at.to_f }
      end
    end
  end
end
