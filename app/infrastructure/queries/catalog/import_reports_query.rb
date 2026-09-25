# 🔌 INFRA · Queries::Catalog::ImportReportsQuery
# Rôle : rapports d'import récents de l'écran des imports, filtrables par type, avec le fichier et l'auteur
# ADR  : 0026, 0039
module Queries
  module Catalog
    class ImportReportsQuery
      Row = Data.define(:public_id, :kind, :filename, :status, :total_count, :imported_count, :skipped_count, :error_count,
                        :imported_by_name, :created_at, :finished_at)

      COLUMNS = [
        "import_reports.public_id", "import_reports.kind", "active_storage_blobs.filename", "import_reports.status",
        "import_reports.total_count", "import_reports.imported_count", "import_reports.skipped_count",
        "import_reports.error_count", Arel.sql("users.first_name || ' ' || users.last_name"), "import_reports.created_at",
        "import_reports.finished_at"
      ].freeze

      def call(kind: nil, limit: 50)
        scope = Orm::ImportReport.joins(:imported_by).left_joins(source_attachment: :blob)
        scope = scope.where(kind:) unless kind.nil?
        scope.order(created_at: :desc, id: :desc).limit(limit).pluck(*COLUMNS).map { |values| Row.new(*values) }
      end
    end
  end
end
