# 🔌 INFRASTRUCTURE · Catalog::PurgeOrphanEssentialImagesJob
# Rôle : supprime chaque jour les images de fiche envoyées puis jamais enregistrées depuis plus de 48 h, fichier compris
# ADR  : 0047, 0104
module Catalog
  class PurgeOrphanEssentialImagesJob < ApplicationJob
    GRACE_PERIOD = 48.hours

    # Le nombre supprimé est journalisé, zéro compris : une purge muette ne se distingue pas d'une purge qui ne tourne pas.
    def perform
      deleted = Repositories::Catalog::EssentialImageStore.new.purge_orphans(before: GRACE_PERIOD.ago)
      Rails.logger.info("[#{self.class.name}] #{deleted} orphan essential image(s) deleted")
      deleted
    end
  end
end
