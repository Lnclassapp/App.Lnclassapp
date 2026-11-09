# 🔌 INFRASTRUCTURE · Classroom::GenerateMissingClassroomsJob
# Rôle : job de la génération des classes manquantes : câble GenerateMissingClassrooms sur les repositories réels
# ADR  : 0039, 0052, 0056, 0058
module Classroom
  class GenerateMissingClassroomsJob < ApplicationJob
    # Une seule génération à la fois : une seconde attend que la première soit finie.
    # Le verrou tombe après la limite d'un rapport sans signe de vie, pas au bout des 3 minutes par défaut (ADR-0096 §4.3).
    limits_concurrency to: 1, key: ->(_report_id) { self.class.name }, duration: UseCases::Catalog::StartImport::STALE_AFTER.seconds
    discard_on ActiveJob::DeserializationError

    def perform(report_id)
      result = UseCases::Classroom::GenerateMissingClassrooms.new(
        reports: Repositories::Catalog::ImportReportRepository.new, schools: Repositories::School::SchoolRepository.new,
        classrooms: Repositories::Classroom::ClassroomRepository.new, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
        classroom_plan: Repositories::Classroom::ClassroomPlanRepository.new, users: Repositories::Identity::UserRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new, policy: Policies::School::ManageSchoolPolicy.new, clock: Time.zone
      ).call(report_id:)
      log_failure(result, report_id:)
    end
  end
end
