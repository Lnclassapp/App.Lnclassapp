# 🔌 INFRASTRUCTURE · Shared::ImportJob
# Rôle : job abstrait d'un type d'import : câble RunImport sur les repositories réels et l'adaptateur de sa sous-classe
# ADR  : 0039, 0052
module Shared
  class ImportJob < ApplicationJob
    # Un seul import d'un même type à la fois : un second rapport attend que le premier soit fini.
    limits_concurrency to: 1, key: ->(_report_id) { self.class.name }
    discard_on ActiveJob::DeserializationError

    def perform(report_id)
      UseCases::Catalog::RunImport.new(
        adapter:, schema: schema_validator,
        reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
        users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      ).call(report_id:)
    end

    private

    # Un UseCases::Catalog::Importer, fourni par la sous-classe de chaque lot d'import.
    def adapter
      raise NotImplementedError, "#{self.class} doit définir #adapter"
    end

    # Schémas de config/schemas ; une sous-classe peut en fournir d'autres (tests).
    def schema_validator = Repositories::Catalog::ImportSchemaValidator.new
  end
end
