# 🔌 INFRA · Repositories::Catalog::ImportFileStore
# Rôle : fichiers importés en pièces jointes du rapport, sur le service Active Storage (bucket), jamais sous tmp/
# ADR  : 0039, 0047, 0068
module Repositories
  module Catalog
    class ImportFileStore
      include Ports::Catalog::ImportFileStorePort

      CONTENT_TYPE = "application/json".freeze

      # Le nom du client n'est qu'une métadonnée du blob : la clé de stockage est aléatoire.
      def attach(report_id:, files:)
        Orm::ImportReport.find(report_id).sources.attach(
          files.map { |file| { io: file.io, filename: file.filename, content_type: CONTENT_TYPE } }
        )
        true
      end

      # Les pièces jointes se relisent dans l'ordre où elles ont été attachées, qui est l'ordre d'envoi.
      def read(report_id:)
        Orm::ImportReport.find(report_id).sources_attachments.includes(:blob).order(:id).map do |attachment|
          Entities::Catalog::ImportFile.new(name: attachment.blob.filename.to_s,
                                            content: attachment.blob.download.force_encoding(Encoding::UTF_8))
        end
      end
    end
  end
end
