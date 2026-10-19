# 🔌 INFRA · Queries::Catalog::PublicSitemapQuery
# Rôle : adresses du catalogue public pour /sitemap.xml : niveaux, couples niveau × série et matières qui ont au moins un cours publié
# ADR  : 0099 (§4.4), 0074 (§4.6)
module Queries
  module Catalog
    class PublicSitemapQuery
      # levels : [[slug, lastmod]] par rang ; series : [[level_slug, series_slug, lastmod]] ; materials : [[slug, lastmod]] dans
      # l'ordre du programme. lastmod : le updated_at le plus récent de leurs cours publiés.
      Result = Data.define(:levels, :series, :materials)

      LASTMOD = Arel.sql("MAX(courses.updated_at)")

      # Trois requêtes, quel que soit le nombre de cours. → Result
      def call
        scope = PublicCourses.scope
        Result.new(levels: scope.group("levels.id").order("levels.position").pluck("levels.slug", LASTMOD),
                   series: PublicCourses.series_pairs.map { |level, series, _, lastmod| [ level, series, lastmod ] },
                   materials: scope.group("materials.id").order(*PublicCourses::MATERIAL_ORDER).pluck("materials.slug", LASTMOD))
      end
    end
  end
end
