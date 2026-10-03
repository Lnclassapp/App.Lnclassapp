# 🔌 INFRASTRUCTURE · Communication::PurgeOrphanArticleImagesJob
# Rôle : supprime chaque jour les images d'article envoyées puis jamais enregistrées depuis plus de 48 h, fichier compris
# ADR  : 0047, 0073
module Communication
  class PurgeOrphanArticleImagesJob < ApplicationJob
    # Le délai des fichiers jamais rattachés (Shared::PurgeUnattachedBlobsJob) : une modale peut rester ouverte longtemps.
    GRACE_PERIOD = 48.hours

    # Le nombre supprimé est journalisé, zéro compris : une purge muette ne se distingue pas d'une purge qui ne tourne pas.
    def perform
      deleted = Repositories::Communication::ArticleImageStore.new.purge_orphans(before: GRACE_PERIOD.ago)
      Rails.logger.info("[#{self.class.name}] #{deleted} orphan article image(s) deleted")
      deleted
    end
  end
end
