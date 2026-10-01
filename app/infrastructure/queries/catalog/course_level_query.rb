# 🔌 INFRA · Queries::Catalog::CourseLevelQuery
# Rôle : le niveau et la série du cours d'un contenu (cours, fiche, exercice ou session), que juge ReadOwnLevelPolicy
# ADR  : 0035 (amendement du 2026-10-01)
module Queries
  module Catalog
    class CourseLevelQuery
      # Une seule clé : le slug ou l'id du cours, le public_id ou l'id d'un exercice, le public_id d'une session.
      # → { level_id:, series_id: } | nil (inconnu)
      def call(course_slug: nil, course_id: nil, exercise_public_id: nil, exercise_id: nil, session_public_id: nil)
        scope = if course_slug then Orm::Course.where(slug: course_slug)
        elsif course_id then Orm::Course.where(id: course_id)
        elsif exercise_public_id then Orm::Course.joins(essentials: :exercises).where(exercises: { public_id: exercise_public_id })
        elsif exercise_id then Orm::Course.joins(essentials: :exercises).where(exercises: { id: exercise_id })
        else Orm::Course.joins(essentials: { exercises: :exercise_sessions }).where(exercise_sessions: { public_id: session_public_id })
        end
        level_id, series_id = scope.pick(:level_id, :series_id)
        { level_id:, series_id: } if level_id
      end
    end
  end
end
