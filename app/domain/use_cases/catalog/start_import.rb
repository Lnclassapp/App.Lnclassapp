# 🧠 DOMAINE · UseCases::Catalog::StartImport
# Rôle : reçoit un envoi d'import (1 à N fichiers) : rapport queued, fichiers stockés, job du type mis en file ; rien n'est lu ici
# ADR  : 0028, 0039, 0047, 0052, 0068
module UseCases
  module Catalog
    class StartImport
      # Au-delà, un rapport encore queued, validating ou importing vient d'un job tué ou jamais pris (déploiement, worker
      # arrêté). Décision du porteur (2026-09-27, ADR-0039) : 10 min, quand un import normal dure moins de 2 min.
      STALE_AFTER = 10 * 60

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
        created = @reports.create(kind: dto.kind, checksum_sha256: dto.checksum_sha256, imported_by_id: actor.user_id, at: now,
                                  files: file_reports(dto.files))
        @files.attach(report_id: created.value.id, files: dto.files) if created.success?
        created
      end

      # Les noms d'affichage sont fixés ici, une fois : deux fichiers du même nom restent distincts (ADR-0068).
      def file_reports(uploads)
        names = Entities::Catalog::ImportFileReport.display_names(uploads.map { it.filename.to_s })
        uploads.zip(names).map { |upload, name| Entities::Catalog::ImportFileReport.new(name:, byte_size: upload.byte_size) }
      end
    end
  end
end
