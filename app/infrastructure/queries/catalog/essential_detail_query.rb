# 🔌 INFRA · Queries::Catalog::EssentialDetailQuery
# Rôle : une fiche essentielle, son cours et ses exercices ; pour un élève, sa progression, ses assignations et sa lacune
# ADR  : 0026, 0028, 0033, 0035, 0043, 0048, 0072 · UDR : 0015
module Queries
  module Catalog
    class EssentialDetailQuery
      Row = Data.define(:essential, :course, :exercises, :pending_gap)
      # content : ActionText::Content, rendu par Action Text (assaini, calque .trix-content), ou nil.
      EssentialRow = Data.define(:slug, :name, :subtitle, :status, :content)
      CourseRow = Data.define(:slug, :name, :status, :level_name, :series_name, :material_name, :material_category)
      # Hors élève : assigned_to_my_classroom vaut false, badge_level (symbole de Grading), best_score_percent et
      # started_session_public_id valent nil.
      ExerciseRow = Data.define(:public_id, :title, :description, :exercise_type, :status, :questions_count,
                                :assigned_to_my_classroom, :badge_level, :best_score_percent, :started_session_public_id)
      GapRow = Data.define(:public_id, :opened_at)

      HEADER_COLUMNS = %w[essentials.id essentials.slug essentials.name essentials.subtitle essentials.status
                          courses.slug courses.name courses.status levels.name series.name materials.name
                          materials.category].freeze
      EXERCISE_COLUMNS = %i[id public_id title description exercise_type status].freeze
      NO_PROGRESS = [ nil, nil, nil ].freeze

      # → Row | nil (fiche inconnue, ou lue sous un autre cours). La lecture d'un brouillon est l'affaire de
      # ReadPublishedPolicy, en amont ; include_unpublished (équipe) liste aussi les exercices en brouillon ou archivés.
      def call(course_slug:, slug:, student_id: nil, include_unpublished: false)
        essential_id, *values =
          Orm::Essential.joins(course: %i[level material]).joins("LEFT OUTER JOIN series ON series.id = courses.series_id")
                        .where(slug:, courses: { slug: course_slug }).pick(*HEADER_COLUMNS)
        return if essential_id.nil?

        Row.new(essential: essential_row(essential_id, values.take(4)), course: CourseRow.new(*values.drop(4)),
                exercises: exercises(essential_id, student_id, include_unpublished),
                pending_gap: pending_gap(essential_id, student_id))
      end

      private

      def essential_row(id, values)
        content = ActionText::RichText.where(record_type: Orm::Essential.name, record_id: id, name: "content").pick(:body)
        EssentialRow.new(*values, content)
      end

      def exercises(essential_id, student_id, include_unpublished)
        scope = Orm::Exercise.where(essential_id:).order(:position, :id)
        scope = scope.where(status: "published") unless include_unpublished
        rows = scope.pluck(*EXERCISE_COLUMNS)
        ids = rows.map(&:first)
        questions = Orm::Question.where(exercise_id: ids).group(:exercise_id).count
        progress = student_id ? progress(ids, student_id) : {}
        assigned = student_id ? assigned_ids(ids, student_id) : Set.new
        rows.map do |id, *values|
          ExerciseRow.new(*values, questions.fetch(id, 0), assigned.include?(id), *progress.fetch(id, NO_PROGRESS))
        end
      end

      # { exercise_id => [badge_level, best_score_percent, started_session_public_id] }, trois requêtes pour la fiche.
      def progress(ids, student_id)
        sessions = Orm::ExerciseSession.where(student_id:, exercise_id: ids)
        best = sessions.where(status: "completed").group(:exercise_id).maximum(:score_percent)
        started = sessions.where(status: "started").pluck(:exercise_id, :public_id).to_h
        badges = Orm::ExerciseBadge.where(student_id:, exercise_id: ids).pluck(:exercise_id, :level).to_h { |id, level| [ id, level.to_sym ] }
        ids.to_h { |id| [ id, [ badges[id], best[id], started[id] ] ] }
      end

      # Assigné directement à la classe principale active de l'élève (ADR-0048) ; ADR-0072 §4.1 : seul un exercice
      # s'assigne, il ne l'est plus par sa fiche ni par son cours.
      def assigned_ids(ids, student_id)
        classrooms = Orm::ClassroomStudent.joins(:classroom)
                                          .where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                                          .select(:classroom_id)
        Orm::ClassroomAssignment.where(classroom_id: classrooms, status: "active", assignable_type: "Exercise", assignable_id: ids)
                                .pluck(:assignable_id).to_set
      end

      # Une seule lacune en attente par élève et par fiche, garantie en base (ADR-0043).
      def pending_gap(essential_id, student_id)
        return if student_id.nil?

        public_id, opened_at = Orm::KnowledgeGap.where(student_id:, essential_id:, status: "pending").pick(:public_id, :created_at)
        GapRow.new(public_id:, opened_at:) if public_id
      end
    end
  end
end
