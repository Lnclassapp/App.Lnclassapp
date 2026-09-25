# 🔌 INFRA · Queries::School::SchoolOptionsQuery
# Rôle : options des formulaires : DRENA par nom, puis les établissements d'une DRENA
# ADR  : 0026, 0034
module Queries
  module School
    class SchoolOptionsQuery
      DrenaRow = Data.define(:public_id, :slug, :name)
      SchoolRow = Data.define(:public_id, :name)

      def drenas
        Orm::Drena.order(:name).pluck(:public_id, :slug, :name).map { |values| DrenaRow.new(*values) }
      end

      def schools_for(drena_public_id:, status: "active")
        Orm::School.joins(:drena).where(drenas: { public_id: drena_public_id }, status:).order(:name)
                   .pluck(:public_id, :name).map { |values| SchoolRow.new(*values) }
      end
    end
  end
end
