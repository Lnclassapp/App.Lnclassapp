# 🔌 INFRASTRUCTURE · Communication::PublishScheduledMessagesJob
# Rôle : toutes les 5 minutes (config/recurring.yml), publie les annonces programmées dont l'heure est venue
# ADR  : 0045, 0052, 0078
module Communication
  class PublishScheduledMessagesJob < ApplicationJob
    def perform
      published = UseCases::Communication::PublishScheduledMessages.new(
        messages: Repositories::Communication::MessageRepository.new, users: Repositories::Identity::UserRepository.new,
        teachings: Repositories::Classroom::TeachingRepository.new, policy: Policies::Communication::PublishPolicy.new,
        teacher_flag: -> { Rails.configuration.x.pilot_flags[:teacher_announcements_enabled] },
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      ).call.value
      Rails.logger.info("[#{self.class.name}] #{published} scheduled announcement(s) published")
      published
    end
  end
end
