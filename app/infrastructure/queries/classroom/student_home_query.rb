# 🔌 INFRA · Queries::Classroom::StudentHomeQuery
# Rôle : accueil élève (CL-23, TR-04, AS-36) : classe principale, exercices assignés publiés et progression, activité, lacunes
# ADR  : 0026, 0033, 0035, 0043, 0048 · UDR : 0010
module Queries
  module Classroom
    class StudentHomeQuery
      Row = Data.define(:school_name, :level_name, :classroom_name, :join_code_display, :classmates_count,
                        :assigned_exercises, :recent_sessions, :pending_gaps)
      # badge_level : bronze, silver, gold, diamond ou nil ; started_session_public_id : la session à reprendre, ou nil.
      ExerciseRow = Data.define(:public_id, :title, :material_name, :material_category, :badge_level,
                                :best_score_percent, :completed_count, :started_session_public_id)
      SessionRow = Data.define(:public_id, :exercise_title, :score_percent, :completed_at)
      GapRow = Data.define(:essential_name, :essential_slug, :course_slug)

      RECENT_SESSIONS = 10
      HEADER_COLUMNS = [ "classrooms.id", "schools.name", "levels.name", "classrooms.name", "classrooms.join_code" ].freeze
      EXERCISE_COLUMNS = [ "exercises.id", "exercises.public_id", "exercises.title", "materials.name", "materials.category",
                           "essentials.id", "courses.id", "essentials.position", "exercises.position" ].freeze

      # → Row | nil (aucune classe principale active : l'élève n'a pas d'accueil)
      def call(student_id:)
        classroom_id, school_name, level_name, classroom_name, join_code =
          Orm::ClassroomStudent.joins(classroom: %i[school level])
                               .where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                               .pick(*HEADER_COLUMNS)
        return if classroom_id.nil?

        Row.new(school_name:, level_name:, classroom_name:, join_code_display: Entities::Classroom::JoinCode.display(join_code),
                classmates_count: Orm::ClassroomStudent.where(classroom_id:, left_at: nil).count,
                assigned_exercises: assigned_exercises(classroom_id, student_id),
                recent_sessions: recent_sessions(student_id:), pending_gaps: pending_gaps(student_id))
      end

      # Lue seule par le frame différé de l'activité récente.
      def recent_sessions(student_id:)
        Orm::ExerciseSession.joins(:exercise).where(student_id:, status: "completed")
                            .order(completed_at: :desc, id: :desc).limit(RECENT_SESSIONS)
                            .pluck(:public_id, "exercises.title", :score_percent, :completed_at)
                            .map { |public_id, exercise_title, score_percent, completed_at| SessionRow.new(public_id:, exercise_title:, score_percent:, completed_at:) }
      end

      private

      # Le plus récemment assigné d'abord ; un exercice atteint par plusieurs assignations n'apparaît qu'une fois.
      def assigned_exercises(classroom_id, student_id)
        assigned_at = Orm::ClassroomAssignment.where(classroom_id:, status: "active")
                                              .pluck(:assignable_type, :assignable_id, :assigned_at)
                                              .to_h { |type, id, at| [ [ type, id ], at ] }
        rows = published_exercises(assigned_at.keys).pluck(*EXERCISE_COLUMNS).sort_by do |id, *, essential_id, course_id, essential_position, position|
          latest = [ [ "Exercise", id ], [ "Essential", essential_id ], [ "Course", course_id ] ].filter_map { assigned_at[it] }.max
          [ -latest.to_f, course_id, essential_position, position ]
        end
        exercise_rows(rows, student_id)
      end

      # Un exercice publié dont la fiche et le cours le sont aussi (ADR-0035).
      def published_exercises(keys)
        ids = ->(type) { keys.filter_map { |key_type, id| id if key_type == type } }
        scope = Orm::Exercise.joins(essential: { course: :material })
                             .where(status: "published", essentials: { status: "published" }, courses: { status: "published" })
        scope.where(id: ids.call("Exercise")).or(scope.where(essential_id: ids.call("Essential")))
             .or(scope.where(essentials: { course_id: ids.call("Course") }))
      end

      def exercise_rows(rows, student_id)
        ids = rows.map(&:first)
        completed = Orm::ExerciseSession.where(student_id:, exercise_id: ids, status: "completed").group(:exercise_id)
                                        .pluck(:exercise_id, Arel.sql("MAX(score_percent)"), Arel.sql("COUNT(*)"))
                                        .to_h { |id, best, count| [ id, [ best, count ] ] }
        started = Orm::ExerciseSession.where(student_id:, exercise_id: ids, status: "started").pluck(:exercise_id, :public_id).to_h
        badges = Orm::ExerciseBadge.where(student_id:, exercise_id: ids).pluck(:exercise_id, :level).to_h
        rows.map do |id, public_id, title, material_name, material_category|
          best_score_percent, completed_count = completed.fetch(id, [ nil, 0 ])
          ExerciseRow.new(public_id:, title:, material_name:, material_category:, badge_level: badges[id], best_score_percent:,
                          completed_count:, started_session_public_id: started[id])
        end
      end

      # Une lacune dont la fiche n'est plus publiée n'a plus de page à ouvrir : elle n'est pas proposée.
      def pending_gaps(student_id)
        Orm::KnowledgeGap.joins(essential: :course)
                         .where(student_id:, status: "pending", essentials: { status: "published" }, courses: { status: "published" })
                         .order(created_at: :desc, id: :desc).pluck("essentials.name", "essentials.slug", "courses.slug")
                         .map { |essential_name, essential_slug, course_slug| GapRow.new(essential_name:, essential_slug:, course_slug:) }
      end
    end
  end
end
