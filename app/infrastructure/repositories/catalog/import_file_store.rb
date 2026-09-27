# 🔌 INFRA · Repositories::Catalog::ImportFileStore
# Rôle : fichier importé en pièce jointe du rapport, sur le service Active Storage (bucket), jamais sous tmp/
# ADR  : 0039, 0047
module Repositories
  module Catalog
    class ImportFileStore
      include Ports::Catalog::ImportFileStorePort

      CONTENT_TYPE = "application/json".freeze

      # Le nom du client n'est qu'une métadonnée du blob : la clé de stockage est aléatoire.
      def attach(report_id:, io:, filename:)
        Orm::ImportReport.find(report_id).source.attach(io:, filename:, content_type: CONTENT_TYPE)
        true
      end

      def read(report_id:)
        Orm::ImportReport.find(report_id).source.download.force_encoding(Encoding::UTF_8)
      end
    end
  end
end
