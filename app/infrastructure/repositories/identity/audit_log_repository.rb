# 🔌 INFRA · Repositories::Identity::AuditLogRepository
# Rôle : journal d'audit en ajout seul ; une action hors liste fermée est refusée ; l'IP s'efface après 12 mois
# ADR  : 0050, 0080, 0096
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

      # ADR-0096 : une régénération de masse écrit une ligne par objet changé, en un seul INSERT par lot.
      def record_many(entries:)
        return 0 if entries.empty?

        rows = entries.map do |entry|
          raise ArgumentError, "action d'audit inconnue : #{entry[:action].inspect}" unless Entities::Identity::AuditAction.valid?(entry[:action])

          { action: entry.fetch(:action), actor_id: entry.fetch(:actor_id), subject_type: entry.fetch(:subject_type),
            subject_id: entry.fetch(:subject_id), metadata: entry.fetch(:metadata), created_at: entry.fetch(:at) }
        end
        Orm::AuditEvent.insert_all!(rows).length
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
