# 🔌 INFRA · Repositories::Catalog::ImportQueue
# Rôle : met en file le job d'import d'un type, nommé dans config.x.import_jobs et résolu seulement à l'appel
# ADR  : 0039, 0052, 0096
module Repositories
  module Catalog
    class ImportQueue
      include Ports::Catalog::ImportQueuePort

      # constantize à l'appel : le job d'un lot pas encore livré ne casse ni le chargement ni l'eager_load.
      # perform_later rend false quand la mise en file est refusée (ActiveJob 8.1 avale l'EnqueueError) : on le dit (ADR-0096 §4.3).
      def enqueue(kind:, report_id:)
        Rails.configuration.x.import_jobs.fetch(kind).constantize.perform_later(report_id) != false
      end
    end
  end
end
