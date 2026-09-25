# 🔌 INFRA · Queries::Catalog::MaterialsQuery
# Rôle : matières de l'écran du référentiel, par nom, avec leur catégorie et le nombre de cours et d'enseignants qui les portent
# ADR  : 0026, 0034
module Queries
  module Catalog
    class MaterialsQuery
      Row = Data.define(:slug, :name, :shortname, :category, :courses_count, :teachers_count)

      COLUMNS = [
        "materials.slug", "materials.name", "materials.shortname", "materials.category",
        Arel.sql("(SELECT COUNT(*) FROM courses WHERE courses.material_id = materials.id)"),
        Arel.sql("(SELECT COUNT(*) FROM teacher_profiles WHERE teacher_profiles.material_id = materials.id)")
      ].freeze

      def call
        Orm::Material.order(:name).pluck(*COLUMNS).map { |values| Row.new(*values) }
      end

      # → Row | nil
      def find(slug:)
        Orm::Material.where(slug:).pluck(*COLUMNS).map { |values| Row.new(*values) }.first
      end
    end
  end
end
