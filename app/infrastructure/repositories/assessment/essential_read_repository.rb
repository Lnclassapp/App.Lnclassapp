# 🔌 INFRA · Repositories::Assessment::EssentialReadRepository
# Rôle : enregistre une fiche ouverte par un élève, en un upsert sur (élève, fiche)
# ADR  : 0090 (§4.1)
module Repositories
  module Assessment
    class EssentialReadRepository
      include Ports::Assessment::EssentialReadRepositoryPort

      # Les pannes réelles de la base, que la lecture d'une fiche avale (signalées) : elle s'affiche quand même. Une clé
      # étrangère refusée (fiche supprimée entre-temps) en fait partie. Toute autre erreur (SQL invalide…) est un bogue.
      OUTAGES = [
        ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError, ActiveRecord::StatementTimeout,
        ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::InvalidForeignKey
      ].freeze

      # Une seule requête, sans lecture préalable : deux ouvertures simultanées ne lèvent pas (ON CONFLICT). La dernière
      # ouverture ne recule jamais : une requête arrivée en retard ne remplace pas une ouverture plus récente.
      ON_REOPEN = Arel.sql("last_read_at = GREATEST(essential_reads.last_read_at, EXCLUDED.last_read_at), " \
                           "updated_at = GREATEST(essential_reads.updated_at, EXCLUDED.updated_at)")

      def record(student_id:, essential_id:, at:)
        Orm::EssentialRead.upsert(
          { student_id:, essential_id:, first_read_at: at, last_read_at: at, created_at: at, updated_at: at },
          unique_by: %i[student_id essential_id], on_duplicate: ON_REOPEN, record_timestamps: false
        )
        true
      end
    end
  end
end
