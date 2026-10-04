# 🔌 INFRASTRUCTURE · School::PurgeArchivedStaffJob
# Rôle : supprime chaque nuit les comptes direction archivés depuis 30 jours : câble PurgeArchivedStaff sur les repositories réels
# ADR  : 0036, 0077 (§4.5)
module School
  class PurgeArchivedStaffJob < ApplicationJob
    # Le nombre supprimé est journalisé, zéro compris : une purge muette ne se distingue pas d'une purge qui ne tourne pas.
    # Un compte en échec est signalé par son id seul (aucune donnée personnelle), et repasse la nuit suivante.
    def perform
      at = Time.current - Entities::School::Staff::RETENTION_DAYS.days
      purged = use_case.call(at:).value
      Rails.logger.info("[#{self.class.name}] #{purged.deleted} archived school staff account(s) deleted")
      if purged.failed.any?
        Rails.logger.error("[#{self.class.name}] #{purged.failed.size} account(s) not deleted, user ids: #{purged.failed.join(', ')}")
      end
      purged.deleted
    end

    private

    def use_case
      UseCases::School::PurgeArchivedStaff.new(
        staffs: Repositories::School::StaffRepository.new, users: Repositories::Identity::UserRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, photos: Repositories::Identity::ProfilePhotoStore.new,
        login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        second_factors: Repositories::Identity::SecondFactorRepository.new,
        pin_recoveries: Repositories::Identity::PinRecoveryRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::School::PurgeArchivedStaffPolicy.new,
        clock: Time.zone
      )
    end
  end
end
