# 🔌 INFRA · Queries::Catalog::LevelsQuery
# Rôle : niveaux de l'écran de l'équipe, par position, avec leurs séries et ce qui les utilise (classes, cours)
# ADR  : 0026, 0034, 0036
module Queries
  module Catalog
    class LevelsQuery
      Row = Data.define(:slug, :name, :position, :cycle, :series_names, :classrooms_count, :courses_count)

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
                  classrooms_count: classrooms.fetch(id, 0), courses_count: courses.fetch(id, 0))
        end
      end

      def series_names(level_ids)
        Orm::LevelSeries.joins(:series).where(level_id: level_ids).order("series.name").pluck(:level_id, "series.name")
                        .each_with_object({}) { |(level_id, name), grouped| (grouped[level_id] ||= []) << name }
      end
    end
  end
end
