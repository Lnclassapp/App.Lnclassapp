# 🔌 INFRA · Queries::Catalog::LevelsQuery
# Rôle : niveaux de l'écran de l'équipe, par position : séries, usage (classes, cours), présence dans la génération des classes
# ADR  : 0026, 0030, 0034, 0036
module Queries
  module Catalog
    class LevelsQuery
      Row = Data.define(:slug, :name, :position, :cycle, :series_names, :classrooms_count, :courses_count,
                        :generates_classrooms)

      # Codes reconnus par la génération des classes (ADR-0030) : les clés du plan, barèmes public et privé réunis.
      GENERATED_SLUGS = Entities::Classroom::DefaultClassroomPlan::PLAN.values.flat_map(&:keys).uniq.freeze

      def call = rows(Orm::Level.all)

      # → Row | nil
      def find(slug:) = rows(Orm::Level.where(slug:)).first

      private

      # Une requête par table : niveaux, séries liées, classes, cours.
      def rows(scope)
        levels = scope.order(:position).pluck(:id, :slug, :name, :position, :cycle)
        ids = levels.map(&:first)
        series = series_names(ids)
        classrooms = Orm::Classroom.where(level_id: ids).group(:level_id).count
        courses = Orm::Course.where(level_id: ids).group(:level_id).count

        levels.map do |id, slug, name, position, cycle|
          Row.new(slug:, name:, position:, cycle:, series_names: series.fetch(id, []),
                  classrooms_count: classrooms.fetch(id, 0), courses_count: courses.fetch(id, 0),
                  generates_classrooms: GENERATED_SLUGS.include?(slug))
        end
      end

      def series_names(level_ids)
        Orm::LevelSeries.joins(:series).where(level_id: level_ids).order("series.name").pluck(:level_id, "series.name")
                        .each_with_object({}) { |(level_id, name), grouped| (grouped[level_id] ||= []) << name }
      end
    end
  end
end
