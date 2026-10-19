# 🔌 INFRA · Queries::Catalog::PublicSeriesQuery
# Rôle : page publique d'un niveau et de sa série (/niveaux/:niveau/:serie) : cours de la série et cours communs du niveau, par matière
# ADR  : 0099 (§4.1, §4.2) · UDR : 0115 (§3.1)
module Queries
  module Catalog
    class PublicSeriesQuery
      Named = Data.define(:slug, :name)
      # siblings : [[slug, name]] des autres séries visibles du niveau ; groups : [PublicCourses::Group] ; common : au moins
      # un cours sans série parmi les cours de la page.
      Result = Data.define(:level, :series, :siblings, :groups, :total_count, :common)

      # Un couple absent de level_series (niveau ou série inconnus, série non rattachée) : nil. Trois requêtes : le couple,
      # les séries visibles du niveau, les cours par matière. La règle d'AudienceFilter : la série, ou aucune série.
      # → Result | nil
      def call(level_slug:, series_slug:)
        level_id, series_id, *names = Orm::LevelSeries.joins(:level, :series)
                                                      .where(levels: { slug: level_slug }, series: { slug: series_slug })
                                                      .pick("levels.id", "series.id", "levels.slug", "levels.name", "series.slug", "series.name")
        return unless level_id

        level = Named.new(*names.first(2))
        series = Named.new(*names.last(2))
        siblings = PublicCourses.series_pairs(level_id:).map { it[1, 2] }.reject { it.first == series.slug }
        result = PublicCourses.groups_by_material(PublicCourses.scope.where(level_id:, series_id: [ nil, series_id ]))
        Result.new(level:, series:, siblings:, groups: result.groups, total_count: result.total_count, common: result.common)
      end
    end
  end
end
