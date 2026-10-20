# 🔌 INFRA · Queries::Catalog::PublicLevelsQuery
# Rôle : liste publique des niveaux qui ont un cours publié (/niveaux) et Espace Niveau (/niveaux/:slug) : séries visibles, cours par matière
# ADR  : 0099 (§4.1, §4.2) · UDR : 0113 (§3.2, §3.3, §3.6)
module Queries
  module Catalog
    class PublicLevelsQuery
      # series : [[slug, name]] des séries visibles du niveau (PublicCourses.series_pairs).
      Level = Data.define(:slug, :name, :cycle, :count, :series)
      # groups : [PublicCourses::Group], dans l'ordre du programme.
      Space = Data.define(:slug, :name, :series, :groups, :total_count)

      # Les niveaux qui ont au moins un cours publié, par rang. Deux requêtes. → [Level]
      def levels
        series = PublicCourses.series_pairs.group_by(&:first)
        PublicCourses.scope.group("levels.id").order("levels.position")
                     .pluck("levels.slug", "levels.name", "levels.cycle", Arel.sql("COUNT(*)"))
                     .map { |slug, name, cycle, count| Level.new(slug:, name:, cycle:, count:, series: series.fetch(slug, []).map { it[1, 2] }) }
      end

      # slug : slug figé du niveau. Trois requêtes : le niveau, ses séries visibles, ses cours par matière. → Space | nil
      def space(slug:)
        id, slug, name = Orm::Level.where(slug:).pick(:id, :slug, :name)
        return unless id

        result = PublicCourses.groups_by_material(PublicCourses.scope.where(level_id: id))
        Space.new(slug:, name:, series: PublicCourses.series_pairs(level_id: id).map { it[1, 2] }, groups: result.groups,
                  total_count: result.total_count)
      end
    end
  end
end
