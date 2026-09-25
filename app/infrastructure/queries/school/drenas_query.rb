# 🔌 INFRA · Queries::School::DrenasQuery
# Rôle : écran des DRENA : nom, slug (cible des imports), établissements et classes comptés en SQL, par nom
# ADR  : 0026, 0029, 0034
module Queries
  module School
    class DrenasQuery
      Row = Data.define(:public_id, :slug, :name, :schools_count, :classrooms_count)

      COLUMNS = [ "drenas.public_id", "drenas.slug", "drenas.name", Arel.sql("COUNT(DISTINCT schools.id)"),
                  Arel.sql("COUNT(classrooms.id)") ].freeze

      def call = rows(Orm::Drena.all)

      # → Row | nil
      def find(public_id:) = rows(Orm::Drena.where(public_id:)).first

      private

      def rows(scope)
        scope.left_joins(schools: :classrooms).group("drenas.id").order("drenas.name")
             .pluck(*COLUMNS).map { |values| Row.new(*values) }
      end
    end
  end
end
