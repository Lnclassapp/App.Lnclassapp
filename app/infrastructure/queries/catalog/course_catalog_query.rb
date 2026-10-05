# 🔌 INFRA · Queries::Catalog::CourseCatalogQuery
# Rôle : cartes du catalogue (CA-01), filtrées par niveau, série, matière et nom (FU-47) ; publiés hors équipe ; élève : son niveau seul
# ADR  : 0026, 0028, 0035 · UDR : 0013, 0054, 0069
module Queries
  module Catalog
    class CourseCatalogQuery
      Row = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category, :status)

      COLUMNS = %w[courses.slug courses.name courses.subtitle levels.name series.name materials.name materials.category
                   courses.status].freeze

      # level, material : slugs. Un filtre vide est ignoré, un slug inconnu ne donne aucun cours.
      # series : slug, appliqué seulement avec un niveau (UDR-0069 §3.4) : cours sans série et cours de cette série.
      # search : fragment du nom du cours, sans casse ni accents (UDR-0054 §3.9) ; vide, il est ignoré.
      # audience : Entities::Catalog::LevelAudience d'un élève (la règle de ReadOwnLevelPolicy) ou d'un enseignant (ses
      # classes) ; nil pour les autres rôles. material_id : la matière de l'enseignant ; nil, aucune restriction.
      def call(actor:, level: nil, series: nil, material: nil, search: nil, audience: nil, material_id: nil)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
        # La règle de ReadPublishedPolicy : l'équipe lit tout, les autres ne lisent que le publié.
        scope = scope.where(status: "published") unless actor.team?
        scope = scope.merge(AudienceFilter.courses(audience)) if audience
        scope = scope.where(material_id:) if material_id
        if level.present?
          scope = scope.where(levels: { slug: level })
          scope = of_series(scope, series) if series.present?
        end
        scope = scope.where(materials: { slug: material }) if material.present?
        scope = Queries::Shared::TextSearch.apply(scope, search, columns: [ "courses.name" ])
        scope.order("materials.name", "levels.position", "courses.name", "courses.id").pluck(*COLUMNS).map { Row.new(*it) }
      end

      private

      # La règle d'AudienceFilter, par slug : série vide ou cette série. Le cours sans série n'est gardé que si la série
      # existe, pour qu'une série inconnue ne donne aucun cours (dans la même requête).
      def of_series(scope, series)
        known = Orm::Series.where(slug: series).arel.exists
        scope.where(series: { slug: series }).or(scope.where(series_id: nil).where(known))
      end
    end
  end
end
