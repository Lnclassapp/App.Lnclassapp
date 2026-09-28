# 🔌 INFRASTRUCTURE · Classroom::GenerateMissingClassroomsJob
# Rôle : job de la génération des classes manquantes : câble GenerateMissingClassrooms sur les repositories réels
# ADR  : 0039, 0052, 0056
module Classroom
  class GenerateMissingClassroomsJob < ApplicationJob
    # Une seule génération à la fois : une seconde attend que la première soit finie.
    limits_concurrency to: 1, key: ->(_report_id) { self.class.name }
    discard_on ActiveJob::DeserializationError

    def perform(report_id)
      UseCases::Classroom::GenerateMissingClassrooms.new(
        reports: Repositories::Catalog::ImportReportRepository.new, schools: Repositories::School::SchoolRepository.new,
        classrooms: Repositories::Classroom::ClassroomRepository.new, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
        users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::School::ManageSchoolPolicy.new, clock: Time.zone
      ).call(report_id:)
    end
  end
end
