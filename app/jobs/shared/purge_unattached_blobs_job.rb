# 🔌 INFRASTRUCTURE · Shared::PurgeUnattachedBlobsJob
# Rôle : purge chaque jour les fichiers envoyés puis jamais rattachés depuis plus de 48 h
# ADR  : 0047
module Shared
  class PurgeUnattachedBlobsJob < ApplicationJob
    GRACE_PERIOD = 48.hours

    def perform
      ActiveStorage::Blob.unattached.where(created_at: ...GRACE_PERIOD.ago).find_each(&:purge_later)
    end
  end
end
