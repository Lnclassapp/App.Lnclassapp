# 🔌 INFRA · Queries::Classroom::StudentClassroomQuery
# Rôle : « Ma classe » (CL-22) : la classe principale active, les cours de ses exercices assignés, les fiches à revoir et les exercices traités
# ADR  : 0026, 0035, 0048, 0067, 0072 · UDR : 0011, 0076 §3.2, 0086 §3.3 (has_teacher) · le code de la classe vient de ClassroomHeaderQuery, sous ReadClassroomPolicy
module Queries
  module Classroom
    class StudentClassroomQuery
      # Jamais de liste nominative ni le travail d'un autre élève (UDR-0011). treated_exercises : ce qu'il a terminé, de son niveau.
      # pending_gaps : les GapRow de StudentHomeQuery, les fiches à revoir de l'élève (CA-E3), de son niveau.
      # has_teacher : la classe a au moins un enseignant sur Lnclass ; sinon « Inviter mon enseignant » (UDR-0086 §3.3).
      Row = Data.define(:public_id, :classroom_name, :level_name, :series_name, :school_name, :school_year, :has_teacher,
                        :courses, :pending_gaps, :treated_exercises)
      # assigned_count : les exercices du cours assignés à la classe (ADR-0072 : un cours ne s'assigne plus).
      CourseRow = Data.define(:slug, :name, :material_name, :material_slug, :material_category, :assigned_count)
      # best_score_percent : le meilleur score de l'élève ; last_session_public_id : sa dernière session terminée ;
      # material_slug : la pastille de la matière (UDR-0086 §3.4) ; exercise_type : « fixation » ou « evaluation ».
      TreatedRow = Data.define(:exercise_public_id, :title, :material_name, :material_slug, :material_category, :best_score_percent,
                               :last_session_public_id, :last_completed_at, :exercise_type)

      # has_teacher se lit dans la même requête que l'en-tête : pas de requête de plus (ADR-0067). Un enseignant anonymisé
      # n'est plus sur Lnclass : il ne masque pas « Inviter mon enseignant ».
      HAS_TEACHER = "EXISTS (SELECT 1 FROM teacher_classrooms " \
                    "INNER JOIN users ON users.id = teacher_classrooms.teacher_id AND users.anonymized_at IS NULL " \
                    "WHERE teacher_classrooms.classroom_id = classrooms.id)"
      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "series.name", "schools.name",
                  "classrooms.school_year", Arel.sql(HAS_TEACHER) ].freeze
      COURSE_COLUMNS = [ "courses.slug", "courses.name", "materials.name", "materials.slug", "materials.category",
                         Arel.sql("COUNT(DISTINCT exercises.id)") ].freeze
      # DISTINCT ON garde, par exercice, la dernière session terminée ; la fenêtre lit le meilleur score avant ce tri.
      TREATED_COLUMNS = [ Arel.sql("DISTINCT ON (exercise_sessions.exercise_id) exercises.public_id"), "exercises.title",
                          "materials.name", "materials.slug", "materials.category",
                          Arel.sql("MAX(exercise_sessions.score_percent) OVER (PARTITION BY exercise_sessions.exercise_id)"),
                          "exercise_sessions.public_id", "exercise_sessions.completed_at", "exercises.exercise_type" ].freeze

      # → Row | nil (aucune classe principale active : l'élève n'a pas de classe à ouvrir)
      def call(student_id:)
        primary = Orm::ClassroomStudent.where(student_id:, primary: true, left_at: nil).select(:classroom_id)
        id, public_id, classroom_name, level_name, series_name, school_name, school_year, has_teacher =
          Orm::Classroom.joins(:level, :school).left_joins(:series).where(id: primary, status: "active").pick(*COLUMNS)
        return if id.nil?

        Row.new(public_id:, classroom_name:, level_name:, series_name:, school_name:, school_year:, has_teacher:,
                courses: courses(id, student_id),
                pending_gaps: home.pending_gaps(student_id:), treated_exercises: treated_exercises(student_id))
      end

      private

      # Une seule instance : le niveau de l'élève (own_level) se lit une fois pour les exercices et les fiches à revoir.
      def home = @home ||= StudentHomeQuery.new

      # UDR-0013, amendement du 2026-10-01 : rien d'un autre niveau que celui de l'élève.
      def own_level(student_id)
        @own_level ||= Queries::Catalog::AudienceFilter.courses(Queries::Catalog::StudentAudienceQuery.new.call(student_id:))
      end

      # Les cours publiés d'un exercice publié assigné à la classe ; le plus récemment assigné d'abord.
      def courses(classroom_id, student_id)
        # La leçon d'un exercice se lit par exercises.course_id : un exercice de toute la leçon n'a pas de notion (ADR-0113).
        Orm::Course.joins(:material)
                   .joins("INNER JOIN exercises ON exercises.course_id = courses.id " \
                          "LEFT OUTER JOIN essentials ON essentials.id = exercises.essential_id " \
                          "INNER JOIN classroom_assignments ON classroom_assignments.assignable_type = 'Exercise' " \
                          "AND classroom_assignments.assignable_id = exercises.id")
                   .where(classroom_assignments: { classroom_id:, status: "active" }, status: "published",
                          exercises: { status: "published" })
                   .where("essentials.id IS NULL OR essentials.status = 'published'")
                   .merge(own_level(student_id))
                   .group("courses.id", "materials.id")
                   .order(Arel.sql("MAX(classroom_assignments.assigned_at) DESC"), "courses.id")
                   .pluck(*COURSE_COLUMNS)
                   .map { |slug, name, material_name, material_slug, material_category, assigned_count| CourseRow.new(slug:, name:, material_name:, material_slug:, material_category:, assigned_count:) }
      end

      def treated_exercises(student_id)
        Orm::ExerciseSession.joins(exercise: { course: :material })
                            .where(student_id:, status: "completed").merge(own_level(student_id))
                            .order("exercise_sessions.exercise_id", completed_at: :desc, id: :desc)
                            .pluck(*TREATED_COLUMNS)
                            .map { |values| TreatedRow.new(*values) }
                            .sort_by { -it.last_completed_at.to_f }
      end
    end
  end
end
