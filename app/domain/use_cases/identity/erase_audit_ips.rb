# 🧠 DOMAINE · UseCases::Identity::EraseAuditIps
# Rôle : la tâche du jour efface l'adresse IP des événements d'audit créés avant l'échéance (12 mois) ; l'événement reste
# ADR  : 0028, 0080
module UseCases
  module Identity
    class EraseAuditIps
      def initialize(audit_log:, policy:)
        @audit_log = audit_log
        @policy = policy
      end

      # at : l'échéance (maintenant - AuditRetention::IP_MONTHS). → success(nombre d'événements traités) | :forbidden
      def call(at:, actor: nil)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        Shared::Result.success(@audit_log.erase_ips_before(at:, batch_size: Entities::Identity::AuditRetention::BATCH_SIZE))
      end
    end
  end
end
