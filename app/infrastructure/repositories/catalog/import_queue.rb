# 🔌 INFRA · Repositories::Catalog::ImportQueue
# Rôle : met en file le job d'import d'un type, nommé dans config.x.import_jobs et résolu seulement à l'appel
# ADR  : 0039, 0052
module Repositories
  module Catalog
    class ImportQueue
      include Ports::Catalog::ImportQueuePort

      # constantize à l'appel : le job d'un lot pas encore livré ne casse ni le chargement ni l'eager_load.
      def enqueue(kind:, report_id:)
        Rails.configuration.x.import_jobs.fetch(kind).constantize.perform_later(report_id)
        true
      end
    end
  end
end
