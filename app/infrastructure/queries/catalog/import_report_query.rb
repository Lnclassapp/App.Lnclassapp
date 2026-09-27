# 🔌 INFRA · Queries::Catalog::ImportReportQuery
# Rôle : un rapport d'import pour l'écran de suivi : statut, progression, compteurs, détails et erreurs localisées
# ADR  : 0026, 0039
module Queries
  module Catalog
    class ImportReportQuery
      Row = Data.define(:public_id, :kind, :filename, :status, :total_count, :imported_count, :skipped_count, :error_count,
                        :imported_by_name, :created_at, :finished_at, :processed_count, :details, :import_errors)
      # Une erreur telle que RunImport l'a notée : chemin JSON, motif, valeurs du message.
      ErrorRow = Data.define(:path, :code, :params)

      COLUMNS = (ImportReportsQuery::COLUMNS + [
        "import_reports.processed_count", "import_reports.details", "import_reports.import_errors"
      ]).freeze

      def call(public_id:)
        values = Orm::ImportReport.joins(:imported_by).left_joins(source_attachment: :blob)
                                  .where(public_id:).pick(*COLUMNS)
        return if values.nil?

        *fields, errors = values
        Row.new(*fields, errors.map { |error| ErrorRow.new(path: error["path"], code: error["code"], params: error["params"]) })
      end
    end
  end
end
