# 🔌 INFRA · Queries::Catalog::CourseCatalogQuery
# Rôle : cartes du catalogue (CA-01), filtrées par niveau et matière ; publiés seulement, tous les statuts pour l'équipe
# ADR  : 0026, 0028, 0035 · UDR : 0013
module Queries
  module Catalog
    class CourseCatalogQuery
      Row = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category, :status)

      COLUMNS = %w[courses.slug courses.name courses.subtitle levels.name series.name materials.name materials.category
                   courses.status].freeze

      # level, material : slugs. Un filtre vide est ignoré, un slug inconnu ne donne aucun cours.
      def call(actor:, level: nil, material: nil)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
        # La règle de ReadPublishedPolicy : l'équipe lit tout, les autres ne lisent que le publié.
        scope = scope.where(status: "published") unless actor.team?
        scope = scope.where(levels: { slug: level }) if level.present?
        scope = scope.where(materials: { slug: material }) if material.present?
        scope.order("materials.name", "levels.position", "courses.name", "courses.id").pluck(*COLUMNS).map { Row.new(*it) }
      end
    end
  end
end
