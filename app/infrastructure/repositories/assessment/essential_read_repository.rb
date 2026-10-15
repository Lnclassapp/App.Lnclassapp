# 🔌 INFRA · Repositories::Assessment::EssentialReadRepository
# Rôle : enregistre une fiche ouverte par un élève, en un upsert sur (élève, fiche)
# ADR  : 0090 (§4.1)
module Repositories
  module Assessment
    class EssentialReadRepository
      include Ports::Assessment::EssentialReadRepositoryPort

      # Une seule requête, sans lecture préalable : deux ouvertures simultanées ne lèvent pas (ON CONFLICT). Rails touche
      # updated_at quand la ligne change (record_timestamps).
      def record(student_id:, essential_id:, at:)
        Orm::EssentialRead.upsert(
          { student_id:, essential_id:, first_read_at: at, last_read_at: at, created_at: at, updated_at: at },
          unique_by: %i[student_id essential_id], update_only: %i[last_read_at]
        )
        true
      end
    end
  end
end
