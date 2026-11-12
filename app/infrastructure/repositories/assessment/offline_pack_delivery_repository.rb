# 🔌 INFRA · Repositories::Assessment::OfflinePackDeliveryRepository
# Rôle : trace des remises du corrigé hors ligne (upsert atomique par élève et exercice, première remise gardée)
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, amendement « Devoir à rendre »)
module Repositories
  module Assessment
    class OfflinePackDeliveryRepository
      include Ports::Assessment::OfflinePackDeliveryRepositoryPort

      def record(student_id:, exercise_id:, at:)
        now = Time.current
        Orm::OfflinePackDelivery.upsert(
          { student_id:, exercise_id:, first_delivered_at: at, last_delivered_at: at, created_at: now, updated_at: now },
          unique_by: :index_offline_pack_deliveries_on_student_and_exercise,
          update_only: [], on_duplicate: Arel.sql(<<~SQL.squish)
            last_delivered_at = GREATEST(offline_pack_deliveries.last_delivered_at, EXCLUDED.last_delivered_at),
            first_delivered_at = LEAST(offline_pack_deliveries.first_delivered_at, EXCLUDED.first_delivered_at),
            updated_at = EXCLUDED.updated_at
          SQL
        )
        nil
      end

      def first_delivered_at(student_id:, exercise_id:)
        Orm::OfflinePackDelivery.where(student_id:, exercise_id:).pick(:first_delivered_at)
      end
    end
  end
end
