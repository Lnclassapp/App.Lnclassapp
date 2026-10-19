# 🔌 INFRASTRUCTURE · Assessment::PurgeOrphanQuestionImagesJob
# Rôle : supprime chaque jour les images de question envoyées puis jamais enregistrées depuis plus de 48 h, fichier compris
# ADR  : 0047, 0104
module Assessment
  class PurgeOrphanQuestionImagesJob < ApplicationJob
    GRACE_PERIOD = 48.hours

    def perform
      deleted = Repositories::Assessment::QuestionImageStore.new.purge_orphans(before: GRACE_PERIOD.ago)
      Rails.logger.info("[#{self.class.name}] #{deleted} orphan question image(s) deleted")
      deleted
    end
  end
end
