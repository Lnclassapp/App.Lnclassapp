# 🔌 INFRASTRUCTURE · Classroom::RegenerateClassroomLinksJob
# Rôle : job de la régénération de masse des liens des classes : câble RegenerateClassroomLinks sur les repositories réels
# ADR  : 0052, 0056, 0085, 0096
module Classroom
  class RegenerateClassroomLinksJob < ApplicationJob
    # Une seule régénération des liens à la fois : une seconde attend que la première soit finie.
    # Le verrou tombe après la limite d'un rapport sans signe de vie : un job tué net ne bloque pas le suivant (ADR-0096 §4.3).
    limits_concurrency to: 1, key: ->(_report_id) { self.class.name }, duration: UseCases::Catalog::StartImport::STALE_AFTER.seconds
    discard_on ActiveJob::DeserializationError

    def perform(report_id)
      UseCases::Classroom::RegenerateClassroomLinks.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, reports: Repositories::Catalog::ImportReportRepository.new,
        users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::School::RegenerateCodesInBulkPolicy.new, clock: Time.zone
      ).call(report_id:)
    end
  end
end
