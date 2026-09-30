# 🧠 DOMAINE · Entities::Catalog::ImportReport
# Rôle : rapport persisté d'un import : statut, progression, compteurs, erreurs localisées
# ADR  : 0039, 0068
module Entities
  module Catalog
    # total_count = imported_count + skipped_count + error_count ; import_errors : 1 000 au plus ;
    # files : [ImportFileReport], dans l'ordre d'envoi (vide pour un rapport sans fichier)
    ImportReport = Data.define(:id, :public_id, :kind, :status, :format_version, :total_count, :imported_count,
                               :skipped_count, :error_count, :processed_count, :details, :import_errors,
                               :imported_by_id, :started_at, :finished_at, :files) do
      def initialize(files: [], **) = super
      def running? = ImportReport::RUNNING.include?(status)
    end
    ImportReport::STATUSES = %w[queued validating importing completed rejected failed].freeze
    ImportReport::RUNNING = %w[queued validating importing].freeze
  end
end
