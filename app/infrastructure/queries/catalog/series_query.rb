# 🔌 INFRA · Queries::Catalog::SeriesQuery
# Rôle : écran des séries : une ligne par série (niveaux liés, classes et cours qui la portent) et la matrice niveau × série
# ADR  : 0026, 0034, 0036
module Queries
  module Catalog
    class SeriesQuery
      Row = Data.define(:slug, :name, :level_names, :classrooms_count, :courses_count)
      Column = Data.define(:id, :slug, :name)
      Cell = Data.define(:level_slug, :level_name, :series_slug, :series_name, :linked, :used)
      # linked : couples liés ; used : couples portés par une classe ou un cours. Deux Set de [level_id, series_id].
      Matrix = Data.define(:levels, :series, :linked, :used) do
        def cell(level, series)
          pair = [ level.id, series.id ]
          Cell.new(level_slug: level.slug, level_name: level.name, series_slug: series.slug, series_name: series.name,
                   linked: linked.include?(pair), used: used.include?(pair))
        end
      end

      # → [Row], triées par nom
      def call = rows(Orm::Series.all)

      # → Row | nil
      def find(slug:) = rows(Orm::Series.where(slug:)).first

      # Niveaux par position en lignes, séries par nom en colonnes.
      def matrix = build_matrix(Orm::Level.all, Orm::Series.all)

      # → Cell | nil, quand le niveau ou la série n'existe pas
      def cell(level_slug:, series_slug:)
        matrix = build_matrix(Orm::Level.where(slug: level_slug), Orm::Series.where(slug: series_slug))
        return nil if matrix.levels.empty? || matrix.series.empty?

        matrix.cell(matrix.levels.first, matrix.series.first)
      end

      private

      def rows(scope)
        records = scope.order(:name).pluck(:id, :slug, :name)
        ids = records.map(&:first)
        level_names = Orm::LevelSeries.joins(:level).where(series_id: ids).order("levels.position")
                                      .pluck(:series_id, "levels.name")
                                      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) { |(id, name), names| names[id] << name }
        classrooms = Orm::Classroom.where(series_id: ids).group(:series_id).count
        courses = Orm::Course.where(series_id: ids).group(:series_id).count
        records.map do |id, slug, name|
          Row.new(slug:, name:, level_names: level_names[id], classrooms_count: classrooms.fetch(id, 0), courses_count: courses.fetch(id, 0))
        end
      end

      def build_matrix(level_scope, series_scope)
        levels = level_scope.order(:position).pluck(:id, :slug, :name).map { Column.new(*it) }
        series = series_scope.order(:name).pluck(:id, :slug, :name).map { Column.new(*it) }
        pairs = { level_id: levels.map(&:id), series_id: series.map(&:id) }
        used = [ Orm::Classroom, Orm::Course ].flat_map { it.where(pairs).distinct.pluck(:level_id, :series_id) }
        Matrix.new(levels:, series:, linked: Orm::LevelSeries.where(pairs).pluck(:level_id, :series_id).to_set, used: used.to_set)
      end
    end
  end
end
