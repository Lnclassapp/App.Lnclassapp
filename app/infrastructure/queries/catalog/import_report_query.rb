# 🔌 INFRA · Queries::Catalog::ImportReportQuery
# Rôle : un rapport d'import pour l'écran de suivi : statut, progression, compteurs, détails et erreurs localisées
# ADR  : 0026, 0039, 0068
module Queries
  module Catalog
    class ImportReportQuery
      Row = Data.define(:public_id, :kind, :filename, :status, :total_count, :imported_count, :skipped_count, :error_count,
                        :imported_by_name, :created_at, :finished_at, :file_count, :processed_count, :details, :import_errors,
                        :files)
      # Une erreur telle que RunImport l'a notée : chemin JSON, motif, valeurs du message, fichier d'un envoi multiple.
      ErrorRow = Data.define(:path, :code, :params, :file) do
        def initialize(path:, code:, params:, file: nil) = super
      end
      # Le bilan d'un fichier (ADR-0068) ; reason : ErrorRow du motif d'un fichier refusé, sinon nil.
      FileRow = Data.define(:name, :status, :reason, :imported, :skipped, :errors)

      COLUMNS = (ImportReportsQuery::COLUMNS + [
        "import_reports.processed_count", "import_reports.details", "import_reports.import_errors", "import_reports.files"
      ]).freeze

      def call(public_id:)
        values = Orm::ImportReport.joins(:imported_by).where(public_id:).pick(*COLUMNS)
        return if values.nil?

        *fields, errors, files = values
        Row.new(*fields, errors.map { |error| error_row(error) }, files.map { |file| file_row(file) })
      end

      private

      def error_row(error) = ErrorRow.new(path: error["path"], code: error["code"], params: error["params"], file: error["file"])

      def file_row(file)
        reason = file["reason"] && ErrorRow.new(path: "$", code: file["reason"]["code"], params: file["reason"]["params"])
        FileRow.new(name: file["name"], status: file["status"], reason:, imported: file["imported"], skipped: file["skipped"],
                    errors: file["errors"])
      end
    end
  end
end
