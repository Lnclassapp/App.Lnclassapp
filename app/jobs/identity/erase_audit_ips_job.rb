# 🔌 INFRASTRUCTURE · Identity::EraseAuditIpsJob
# Rôle : efface chaque nuit l'adresse IP des événements d'audit de plus de 12 mois ; câble EraseAuditIps sur le vrai journal
# ADR  : 0080
module Identity
  class EraseAuditIpsJob < ApplicationJob
    # Le nombre traité est journalisé, zéro compris : une tâche muette ne se distingue pas d'une tâche qui ne tourne pas.
    def perform
      at = Time.current - Entities::Identity::AuditRetention::IP_MONTHS.months
      erased = use_case.call(at:).value
      Rails.logger.info("#{erased} audit event IP(s) erased")
      erased
    end

    private

    def use_case
      UseCases::Identity::EraseAuditIps.new(audit_log: Repositories::Identity::AuditLogRepository.new,
                                            policy: Policies::Identity::EraseAuditIpsPolicy.new)
    end
  end
end
