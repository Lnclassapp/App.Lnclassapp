# 🔌 INFRASTRUCTURE · School::RegenerateSchoolCodesJob
# Rôle : job de la régénération de masse des codes d'établissement : câble RegenerateSchoolCodes sur les repositories réels
# ADR  : 0052, 0056, 0096
module School
  class RegenerateSchoolCodesJob < ApplicationJob
    # Une seule régénération des codes à la fois : une seconde attend que la première soit finie.
    limits_concurrency to: 1, key: ->(_report_id) { self.class.name }
    discard_on ActiveJob::DeserializationError

    def perform(report_id)
      UseCases::School::RegenerateSchoolCodes.new(
        schools: Repositories::School::SchoolRepository.new, reports: Repositories::Catalog::ImportReportRepository.new,
        users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::School::RegenerateCodesInBulkPolicy.new, clock: Time.zone
      ).call(report_id:)
    end
  end
end
