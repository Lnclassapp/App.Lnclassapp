# 🔌 INFRA · Queries::Catalog::ReferentialOptionsQuery
# Rôle : options des formulaires : niveaux par position, séries permises de chaque niveau, matières avec leur catégorie
# ADR  : 0026, 0034
module Queries
  module Catalog
    class ReferentialOptionsQuery
      Row = Data.define(:levels, :series_by_level, :materials)
      LevelRow = Data.define(:id, :slug, :name, :cycle)
      SeriesRow = Data.define(:id, :slug, :name)
      MaterialRow = Data.define(:id, :slug, :name, :shortname, :category)

      # series_by_level : { level_id => [SeriesRow] }, triées par nom ; un niveau sans série n'y figure pas.
      def call
        Row.new(
          levels: Orm::Level.order(:position).pluck(:id, :slug, :name, :cycle).map { |values| LevelRow.new(*values) },
          series_by_level: series_by_level,
          materials: Orm::Material.order(:name).pluck(:id, :slug, :name, :shortname, :category).map { |values| MaterialRow.new(*values) }
        )
      end

      private

      def series_by_level
        Orm::LevelSeries.joins(:series).order("series.name")
                        .pluck(:level_id, "series.id", "series.slug", "series.name")
                        .each_with_object({}) { |(level_id, *series), grouped| (grouped[level_id] ||= []) << SeriesRow.new(*series) }
      end
    end
  end
end
