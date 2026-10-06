# 🔌 INFRA · Repositories::Identity::AuditLogRepository
# Rôle : journal d'audit en ajout seul ; une action hors liste fermée est refusée ; l'IP s'efface après 12 mois
# ADR  : 0050, 0080
module Repositories
  module Identity
    class AuditLogRepository
      include Ports::Identity::AuditLogPort

      def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
        raise ArgumentError, "action d'audit inconnue : #{action.inspect}" unless Entities::Identity::AuditAction.valid?(action)

        Orm::AuditEvent.create!(action:, actor_id:, subject_type:, subject_id:, metadata:,
                                ip_address: ip.to_s.first(45).presence, created_at: at)
        true
      end

      # Un lot par requête : aucun verrou long, même au premier passage sur tout le journal. Seule écriture après coup sur le
      # journal en ajout seul (ADR-0050) : update_all passe outre readonly?, et ne vide que ip_address (ADR-0080).
      def erase_ips_before(at:, batch_size:)
        erased = 0
        loop do
          ids = Orm::AuditEvent.where(created_at: ...at).where.not(ip_address: nil).limit(batch_size).pluck(:id)
          break erased if ids.empty?

          erased += Orm::AuditEvent.where(id: ids).update_all(ip_address: nil)
        end
      end
    end
  end
end
