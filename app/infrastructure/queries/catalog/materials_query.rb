# 🔌 INFRA · Queries::Catalog::MaterialsQuery
# Rôle : matières de l'écran du référentiel, par nom, avec leur catégorie et le nombre de cours et d'enseignants qui les portent
# ADR  : 0026, 0034, 0103 (§4.5 : un enseignant compte dans chacune de ses matières)
module Queries
  module Catalog
    class MaterialsQuery
      Row = Data.define(:slug, :name, :shortname, :category, :courses_count, :teachers_count)

      COLUMNS = [
        "materials.slug", "materials.name", "materials.shortname", "materials.category",
        Arel.sql("(SELECT COUNT(*) FROM courses WHERE courses.material_id = materials.id)"),
        # Les enseignants rattachés qui la portent dans au moins un de leurs établissements, chacun une fois.
        Arel.sql("(SELECT COUNT(DISTINCT teacher_school_materials.teacher_id) FROM teacher_school_materials " \
                 "JOIN teacher_schools ON teacher_schools.teacher_id = teacher_school_materials.teacher_id " \
                 "AND teacher_schools.school_id = teacher_school_materials.school_id " \
                 "WHERE teacher_school_materials.material_id = materials.id)")
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
