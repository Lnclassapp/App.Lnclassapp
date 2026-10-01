# 🔌 INFRA · Queries::Catalog::CourseCatalogQuery
# Rôle : cartes du catalogue (CA-01), filtrées par niveau, matière et nom (FU-47) ; publiés hors équipe ; élève : son niveau seul
# ADR  : 0026, 0028, 0035 · UDR : 0013, 0054
module Queries
  module Catalog
    class CourseCatalogQuery
      Row = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category, :status)

      COLUMNS = %w[courses.slug courses.name courses.subtitle levels.name series.name materials.name materials.category
                   courses.status].freeze

      # level, material : slugs. Un filtre vide est ignoré, un slug inconnu ne donne aucun cours.
      # search : fragment du nom du cours, sans casse ni accents (UDR-0054 §3.9) ; vide, il est ignoré.
      # audience : Entities::Catalog::LevelAudience d'un élève, la règle de ReadOwnLevelPolicy ; nil pour les autres rôles.
      def call(actor:, level: nil, material: nil, search: nil, audience: nil)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
        # La règle de ReadPublishedPolicy : l'équipe lit tout, les autres ne lisent que le publié.
        scope = scope.where(status: "published") unless actor.team?
        scope = for_audience(scope, audience) if audience
        scope = scope.where(levels: { slug: level }) if level.present?
        scope = scope.where(materials: { slug: material }) if material.present?
        scope = Queries::Shared::TextSearch.apply(scope, search, columns: [ "courses.name" ])
        scope.order("materials.name", "levels.position", "courses.name", "courses.id").pluck(*COLUMNS).map { Row.new(*it) }
      end

      private

      # Un cours du niveau d'une classe, sans série ou de la série de cette classe ; aucune classe : aucun cours.
      def for_audience(scope, audience)
        return scope.none if audience.empty?

        audience.pairs.map { |level_id, series_id| Orm::Course.where(level_id:, series_id: [ nil, series_id ].uniq) }
                .reduce(:or).then { scope.merge(it) }
      end
    end
  end
end
