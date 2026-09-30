# 🔌 INFRA · Repositories::Catalog::ImportReportRepository
# Rôle : rapports d'import ; un seul en cours par type (index partiel), progression et bilan persistés
# ADR  : 0039, 0068
module Repositories
  module Catalog
    class ImportReportRepository
      include Ports::Catalog::ImportReportRepositoryPort

      Kind = Entities::Catalog::ImportKind

      def create(kind:, checksum_sha256:, imported_by_id:, at:, files: [])
        record = Orm::ImportReport.new(kind:, checksum_sha256:, imported_by_id:, status: "queued", files: files.map { dump_file(it) },
                                       created_at: at, updated_at: at)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::ImportReport.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { kind: [ :already_running ] })
      end

      def find(id:)
        record = Orm::ImportReport.find_by(id:)
        record && map_to_entity(record)
      end

      def find_by_public_id(public_id:)
        record = Orm::ImportReport.find_by(public_id:)
        record && map_to_entity(record)
      end

      def fail_stale(kind:, before:, at:)
        running = Orm::ImportReport.where(status: %w[validating importing], started_at: ...before)
        never_claimed = Orm::ImportReport.where(status: "queued", created_at: ...before)
        Orm::ImportReport.where(kind:).merge(running.or(never_claimed))
                         .update_all(status: "failed", finished_at: at, updated_at: at)
      end

      def claim(id:, at:)
        Orm::ImportReport.where(id:, status: "queued")
                         .update_all(status: "validating", started_at: at, updated_at: at) == 1
      end

      def advance(id:, status:, processed_count:, format_version: nil)
        changes = { status:, processed_count:, updated_at: Time.current }
        changes[:format_version] = format_version if format_version
        Orm::ImportReport.where(id:).update_all(changes)
        true
      end

      def finish(id:, status:, counts:, details:, errors:, at:, files: nil)
        changes = { status:, **counts.slice(:total_count, :imported_count, :skipped_count, :error_count), details:,
                    import_errors: errors.first(Kind::MAX_ERRORS).map { |error| error.to_h.transform_keys(&:to_s) },
                    finished_at: at, updated_at: at }
        changes[:files] = files.map { dump_file(it) } unless files.nil?
        Orm::ImportReport.where(id:).update_all(changes)
        true
      end

      private

      def map_to_entity(record)
        Entities::Catalog::ImportReport.new(
          id: record.id, public_id: record.public_id, kind: record.kind, status: record.status,
          format_version: record.format_version, total_count: record.total_count, imported_count: record.imported_count,
          skipped_count: record.skipped_count, error_count: record.error_count, processed_count: record.processed_count,
          details: record.details, import_errors: record.import_errors.map { |error| map_error(error) },
          imported_by_id: record.imported_by_id, started_at: record.started_at, finished_at: record.finished_at,
          files: record.files.map { |file| map_file(file) }
        )
      end

      def map_error(error)
        Entities::Catalog::ImportError.new(path: error["path"], code: error["code"], params: error["params"].to_h.symbolize_keys,
                                           file: error["file"])
      end

      # Le motif d'un fichier refusé est une ImportError sans chemin propre : son chemin est le fichier (« $ »).
      def dump_file(file)
        file.to_h.merge(reason: file.reason && file.reason.to_h.slice(:code, :params)).transform_keys(&:to_s)
      end

      def map_file(file)
        reason = file["reason"] && Entities::Catalog::ImportError.new(path: "$", code: file["reason"]["code"],
                                                                      params: file["reason"]["params"].to_h.symbolize_keys)
        Entities::Catalog::ImportFileReport.new(name: file["name"], byte_size: file["byte_size"], status: file["status"], reason:,
                                                imported: file["imported"], skipped: file["skipped"], errors: file["errors"])
      end
    end
  end
end
