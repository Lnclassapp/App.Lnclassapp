# 🔌 INFRA · Queries::Catalog::NextExerciseQuery
# Rôle : le prochain exercice de l'élève dans une matière ou une leçon : celui en cours, sinon le suivant du dernier terminé
# ADR  : 0035 · UDR : XXXX parcours matière → exercice §3
module Queries
  module Catalog
    class NextExerciseQuery
      # kind : :resume (session en cours : session_public_id, resume_number) · :start (à commencer, ces deux-là sont nil).
      Row = Data.define(:kind, :exercise_public_id, :title, :lesson_name, :session_public_id, :resume_number)

      NO_NOTION_RANK = 2_147_483_647
      ORDER = [
        CourseCatalogQuery::LESSON_NUMBER, "courses.name", "courses.id",
        Arel.sql("COALESCE(essentials.position, #{NO_NOTION_RANK})"), "exercises.position", "exercises.id"
      ].freeze

      # audience : Entities::Catalog::LevelAudience de l'élève ; material : slug de matière, ou course_slug : slug de leçon.
      # → Row, ou nil (rien à proposer). Deux requêtes au plus : les candidats, puis les sessions de l'élève sur eux.
      def call(student_id:, audience:, material: nil, course_slug: nil)
        candidates = candidates(audience, material, course_slug)
        return if candidates.empty?

        sessions = Orm::ExerciseSession.where(student_id:, exercise_id: candidates.map(&:first))
                                       .pluck(:exercise_id, :status, :public_id, :answered_count, :started_at, :completed_at)
        resume(candidates, sessions) || start(candidates, sessions)
      end

      private

      # [[id, public_id, title, lesson_name], ...] dans l'ordre du programme.
      def candidates(audience, material, course_slug)
        scope = Orm::Exercise.joins(:course).left_joins(:essential)
                             .where(status: "published", archived_at: nil, courses: { status: "published" })
                             .where("essentials.id IS NULL OR essentials.status = 'published'")
                             .merge(AudienceFilter.courses(audience))
        scope = scope.joins(course: :material).where(materials: { slug: material }) if material
        scope = scope.where(courses: { slug: course_slug }) if course_slug
        scope.order(*ORDER).pluck("exercises.id", "exercises.public_id", "exercises.title", "courses.name")
      end

      def resume(candidates, sessions)
        started = sessions.select { it[1] == "started" }.max_by { it[4] }
        return unless started

        _, public_id, title, lesson_name = candidates.find { it.first == started.first }
        Row.new(kind: :resume, exercise_public_id: public_id, title:, lesson_name:, session_public_id: started[2],
                resume_number: started[3] + 1)
      end

      def start(candidates, sessions)
        completed = sessions.select { it[1] == "completed" }
        done = completed.to_set(&:first)
        pending = candidates.reject { done.include?(it.first) }
        last = completed.max_by { it[5] }
        index = last && candidates.index { it.first == last.first }
        found = (pending.find { candidates.index(it) > index } if index) || pending.first
        return unless found

        Row.new(kind: :start, exercise_public_id: found[1], title: found[2], lesson_name: found[3], session_public_id: nil,
                resume_number: nil)
      end
    end
  end
end
