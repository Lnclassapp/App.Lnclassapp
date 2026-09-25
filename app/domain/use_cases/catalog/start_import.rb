# 🧠 DOMAINE · UseCases::Catalog::StartImport
# Rôle : reçoit un fichier d'import : rapport queued, fichier stocké, job du type mis en file ; rien n'est lu ici
# ADR  : 0028, 0039, 0047, 0052
module UseCases
  module Catalog
    class StartImport
      # Au-delà, un rapport encore validating ou importing vient d'un job tué (déploiement).
      STALE_AFTER = 30 * 60

      def initialize(reports:, files:, queue:, transaction:, clock:)
        @reports = reports
        @files = files
        @queue = queue
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Catalog::ImportUploadInput. → Result(ImportReport) | :invalid | :forbidden | :conflict
      def call(actor:, dto:)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        allowed = Entities::Catalog::ImportKind.fetch(dto.kind).authorize(actor:)
        return allowed if allowed.failure?

        now = @clock.now
        @reports.fail_stale(kind: dto.kind, before: now - STALE_AFTER, at: now)
        created = @transaction.call { store(actor, dto, now) }
        @queue.enqueue(kind: dto.kind, report_id: created.value.id) if created.success?
        created
      end

      private

      def store(actor, dto, now)
        created = @reports.create(kind: dto.kind, checksum_sha256: dto.checksum_sha256, imported_by_id: actor.user_id, at: now)
        @files.attach(report_id: created.value.id, io: dto.io, filename: dto.filename) if created.success?
        created
      end
    end
  end
end
