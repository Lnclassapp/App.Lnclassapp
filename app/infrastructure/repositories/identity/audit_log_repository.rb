# 🔌 INFRA · Repositories::Identity::AuditLogRepository
# Rôle : journal d'audit en ajout seul ; une action hors liste fermée est refusée
# ADR  : 0050
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
    end
  end
end
