# 🧠 DOMAINE · UseCases::Catalog::RunImport
# Rôle : moteur d'import partiel : rejet en bloc, validation de tout le fichier, doublons ignorés, écriture par lots rejoués
# ADR  : 0028, 0039, 0050
module UseCases
  module Catalog
    class RunImport
      ROOT_PATH = "$"
      PROGRESS_EVERY = 100
      UNREADABLE = Object.new.freeze

      # Compteurs d'un import ; un élément en erreur compte une fois, quel que soit son nombre d'erreurs.
      class Tally
        attr_reader :errors, :details

        def initialize
          @imported = 0
          @skipped = 0
          @failed = 0
          @errors = []
          @details = {}
        end

        def counts
          { total_count: @imported + @skipped + @failed, imported_count: @imported, skipped_count: @skipped, error_count: @failed }
        end

        def add(written)
          @imported += written.fetch(:imported)
          @details.merge!(written.fetch(:details)) { |_key, current, added| current + added }
          nil
        end

        def skip
          @skipped += 1
          nil
        end

        def invalid(errors)
          @failed += 1
          @errors.concat(errors)
          nil
        end
      end

      # adapter : un UseCases::Catalog::Importer ; schema : Ports::Catalog::ImportSchemaPort.
      def initialize(adapter:, reports:, files:, schema:, users:, audit_log:, transaction:, clock:)
        @adapter = adapter
        @reports = reports
        @files = files
        @schema = schema
        @users = users
        @audit_log = audit_log
        @transaction = transaction
        @clock = clock
      end

      # → Result(ImportReport completed | rejected) | :conflict (déjà pris par un autre job) | :forbidden (droit retiré : failed)
      # Une exception imprévue passe le rapport failed, puis remonte au job.
      def call(report_id:)
        return Shared::Result.failure(:conflict, errors: { base: [ :already_claimed ] }) unless @reports.claim(id: report_id, at: @clock.now)

        @tally = Tally.new
        begin
          run(@reports.find(id: report_id))
        rescue StandardError
          finish(report_id, "failed", [])
          raise
        end
      end

      private

      def run(report)
        kind = Entities::Catalog::ImportKind.fetch(report.kind)
        return forbid(report) if kind.authorize(actor: @users.actor_for(user_id: report.imported_by_id)).failure?

        document = parse(@files.read(report_id: report.id))
        return reject(report, [ error(ROOT_PATH, "json_invalid") ]) if document.equal?(UNREADABLE)

        blocking = envelope_errors(document, kind)
        return reject(report, blocking) if blocking.any?

        @reports.advance(id: report.id, status: "validating", processed_count: 0, format_version: kind.version)
        validate_document(report, kind, document)
      end

      def validate_document(report, kind, document)
        schema_errors = @schema.validate(format: kind.format, version: kind.version, document:)
                               .group_by { |error| error.path[/\A#{Regexp.escape(kind.roots_key)}\[(\d+)\]/, 1]&.to_i }
        return reject(report, schema_errors[nil]) if schema_errors.key?(nil)

        target = @adapter.resolve_target(document:)
        if target.failure?
          return reject(report, [ error(kind.target_key || ROOT_PATH, "unknown_target", value: document[kind.target_key]) ])
        end

        roots = document.fetch(kind.roots_key, [])
        if roots.size > kind.max_roots
          return reject(report, [ error(kind.roots_key, "too_many_roots", max: kind.max_roots, count: roots.size) ])
        end

        items = validate_roots(report, kind, roots, schema_errors, @adapter.prepare(target: target.value))
        write(report, items)
        complete(report)
      end

      def parse(raw)
        JSON.parse(raw)
      rescue JSON::ParserError
        UNREADABLE
      end

      # Le format reçu, s'il est un texte, permet à l'écran de nommer l'import auquel le fichier appartient.
      def format_mismatch(document, kind)
        received = document["format"] if document.is_a?(Hash)
        return error("format", "format_mismatch", expected: kind.format) unless received.is_a?(String)

        error("format", "format_mismatch", expected: kind.format, received:)
      end

      def envelope_errors(document, kind)
        return [ format_mismatch(document, kind) ] unless document.is_a?(Hash) && document["format"] == kind.format
        return [ error("version", "version_unsupported", expected: kind.version) ] unless document["version"] == kind.version

        []
      end

      # Tout le fichier est validé avant la moindre écriture ; les doublons (en base ou plus haut dans le fichier) sont ignorés.
      def validate_roots(report, kind, roots, schema_errors, context)
        seen = Set.new
        roots.each_with_index.filter_map do |root, index|
          path = "#{kind.roots_key}[#{index}]"
          item = verdict(root, path, schema_errors[index], context)
          progress(report, "validating", index + 1)
          keep(item, context, seen)
        end
      end

      # Une erreur de schéma dispense l'adaptateur de valider un élément mal formé.
      def verdict(root, path, schema_errors, context)
        return Entities::Catalog::ImportItem.new(path:, errors: schema_errors) if schema_errors

        @adapter.validate_root(root:, path:, context:)
      end

      def keep(item, context, seen)
        return @tally.invalid(item.errors) unless item.valid?
        return @tally.skip if context.existing_keys.include?(item.key) || !seen.add?(item.key)

        item
      end

      # Par lots de BATCH_SIZE ; un lot refusé est rejoué élément par élément, chacun entier ou pas du tout.
      def write(report, items)
        @reports.advance(id: report.id, status: "importing", processed_count: 0)
        at = @clock.now
        done = 0
        items.each_slice(Entities::Catalog::ImportKind::BATCH_SIZE) do |batch|
          written = @transaction.attempt { @adapter.write(items: batch, author_id: report.imported_by_id, at:) }
          if written.success?
            @tally.add(written.value)
          else
            batch.each { |item| write_one(report, item, at) }
          end
          @reports.advance(id: report.id, status: "importing", processed_count: done += batch.size)
        end
      end

      def write_one(report, item, at)
        written = @transaction.attempt { @adapter.write(items: [ item ], author_id: report.imported_by_id, at:) }
        return @tally.add(written.value) if written.success?

        @tally.invalid([ error(item.path, "write_failed") ])
      end

      def progress(report, status, processed_count)
        @reports.advance(id: report.id, status:, processed_count:) if (processed_count % PROGRESS_EVERY).zero?
      end

      def complete(report)
        finish(report.id, "completed", @tally.errors)
        audit(report, "completed")
        Shared::Result.success(@reports.find(id: report.id))
      end

      # Rejet en bloc : aucune écriture, aucun élément compté.
      def reject(report, errors)
        finish(report.id, "rejected", errors)
        audit(report, "rejected")
        Shared::Result.success(@reports.find(id: report.id))
      end

      # Le droit du type est vérifié à nouveau au lancement : un rôle retiré entre-temps fait échouer l'import.
      def forbid(report)
        finish(report.id, "failed", [])
        Shared::Result.failure(:forbidden)
      end

      # Au-delà de MAX_ERRORS erreurs, seul error_count avance.
      def finish(report_id, status, errors)
        @reports.finish(id: report_id, status:, counts: @tally.counts, details: @tally.details,
                        errors: errors.first(Entities::Catalog::ImportKind::MAX_ERRORS), at: @clock.now)
      end

      def audit(report, status)
        @audit_log.record(action: "import.run", actor_id: report.imported_by_id, at: @clock.now, subject_type: "ImportReport",
                          subject_id: report.id, metadata: { kind: report.kind, status:, **@tally.counts })
      end

      def error(path, code, **params)
        Entities::Catalog::ImportError.new(path:, code:, params:)
      end
    end
  end
end
