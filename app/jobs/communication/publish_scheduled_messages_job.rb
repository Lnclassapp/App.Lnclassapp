# 🔌 INFRASTRUCTURE · Communication::PublishScheduledMessagesJob
# Rôle : toutes les 5 minutes (config/recurring.yml), publie les annonces programmées dont l'heure est venue
# ADR  : 0045, 0052, 0078
module Communication
  class PublishScheduledMessagesJob < ApplicationJob
    def perform
      UseCases::Communication::PublishScheduledMessages.new(
        messages: Repositories::Communication::MessageRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      ).call
    end
  end
end
