# 🔌 INFRA · Queries::Catalog::CourseCatalogQuery
# Rôle : cartes du catalogue (CA-01), filtrées par niveau, série, matière et nom (FU-47), entières ou par page ; publiés hors équipe ; élève : son niveau seul
# ADR  : 0026, 0028, 0035, 0076 · UDR : 0013 (amendement du 2026-10-05), 0054, 0069
module Queries
  module Catalog
    class CourseCatalogQuery
      Row = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category, :status)
      # Chantier politique-cache, lot E4 (UDR-0013, amendement du 2026-10-05) : le catalogue se lit par pages de PER_PAGE
      # cartes, les suivantes chargées au défilement. 24 tient en lignes pleines sur 1, 2 ou 3 colonnes.
      PER_PAGE = 24
      Page = Data.define(:rows, :total_count, :page, :pages)

      COLUMNS = %w[courses.slug courses.name courses.subtitle levels.name series.name materials.name materials.category
                   courses.status].freeze

      # level, material : slugs. Un filtre vide est ignoré, un slug inconnu ne donne aucun cours.
      # series : slug, appliqué seulement avec un niveau (UDR-0069 §3.4) : cours sans série et cours de cette série.
      # search : fragment du nom du cours, sans casse ni accents (UDR-0054 §3.9) ; vide, il est ignoré.
      # audience : Entities::Catalog::LevelAudience d'un élève, la règle de ReadOwnLevelPolicy ; nil pour les autres rôles.
      # page : entier, hors bornes ramené à la plus proche (une adresse forgée « page[]=2 » vaut 1). Deux requêtes : le
      # compte, puis les cartes de la page. → Page
      def call(actor:, page: 1, **filters)
        scope = filtered(actor:, **filters)
        total_count = scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages)
        rows = ordered(scope).offset((page - 1) * PER_PAGE).limit(PER_PAGE).pluck(*COLUMNS).map { Row.new(*it) }
        Page.new(rows:, total_count:, page:, pages:)
      end

      private

      def filtered(actor:, level: nil, series: nil, material: nil, search: nil, audience: nil)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
        # La règle de ReadPublishedPolicy : l'équipe lit tout, les autres ne lisent que le publié.
        scope = scope.where(status: "published") unless actor.team?
        scope = scope.merge(AudienceFilter.courses(audience)) if audience
        if level.present?
          scope = scope.where(levels: { slug: level })
          scope = of_series(scope, series) if series.present?
        end
        scope = scope.where(materials: { slug: material }) if material.present?
        Queries::Shared::TextSearch.apply(scope, search, columns: [ "courses.name" ])
      end

      def ordered(scope) = scope.order("materials.name", "levels.position", "courses.name", "courses.id")

      # La règle d'AudienceFilter, par slug : série vide ou cette série. Le cours sans série n'est gardé que si la série
      # existe, pour qu'une série inconnue ne donne aucun cours (dans la même requête).
      def of_series(scope, series)
        known = Orm::Series.where(slug: series).arel.exists
        scope.where(series: { slug: series }).or(scope.where(series_id: nil).where(known))
      end
    end
  end
end
