# 🔌 INFRA · Queries::Catalog::ImportReportsQuery
# Rôle : rapports d'import récents de l'écran des imports, filtrables par type, avec le fichier et l'auteur
# ADR  : 0026, 0039, 0068
module Queries
  module Catalog
    class ImportReportsQuery
      # filename : le premier fichier de l'envoi ; file_count : le nombre de fichiers (0 pour une génération des classes).
      Row = Data.define(:public_id, :kind, :filename, :status, :total_count, :imported_count, :skipped_count, :error_count,
                        :imported_by_name, :created_at, :finished_at, :file_count)

      # Les noms des fichiers sont gardés dans le rapport (ADR-0068) : aucune jointure sur les pièces jointes.
      FILENAME = Arel.sql("import_reports.files->0->>'name'")
      FILE_COUNT = Arel.sql("jsonb_array_length(import_reports.files)")

      COLUMNS = [
        "import_reports.public_id", "import_reports.kind", FILENAME, "import_reports.status",
        "import_reports.total_count", "import_reports.imported_count", "import_reports.skipped_count",
        "import_reports.error_count", Arel.sql("users.first_name || ' ' || users.last_name"), "import_reports.created_at",
        "import_reports.finished_at", FILE_COUNT
      ].freeze

      def call(kind: nil, limit: 50)
        scope = Orm::ImportReport.joins(:imported_by)
        scope = scope.where(kind:) unless kind.nil?
        scope.order(created_at: :desc, id: :desc).limit(limit).pluck(*COLUMNS).map { |values| Row.new(*values) }
      end
    end
  end
end
