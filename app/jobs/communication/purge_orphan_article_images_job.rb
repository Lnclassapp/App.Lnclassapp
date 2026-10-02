# 🔌 INFRASTRUCTURE · Communication::PurgeOrphanArticleImagesJob
# Rôle : supprime chaque jour les images d'article envoyées puis jamais enregistrées depuis plus de 48 h, fichier compris
# ADR  : 0047, 0073
module Communication
  class PurgeOrphanArticleImagesJob < ApplicationJob
    # Le délai des fichiers jamais rattachés (Shared::PurgeUnattachedBlobsJob) : une modale peut rester ouverte longtemps.
    GRACE_PERIOD = 48.hours

    def perform
      Repositories::Communication::ArticleImageStore.new.purge_orphans(before: GRACE_PERIOD.ago)
    end
  end
end
