# 🧠 DOMAINE · UseCases::Catalog::RunImport
# Rôle : moteur d'import partiel d'un envoi de 1 à N fichiers : refus par fichier, validation de tout l'envoi, doublons,
#         écriture par lots rejoués, bilan par fichier
# ADR  : 0028, 0039, 0050, 0068
module UseCases
  module Catalog
    class RunImport
      ROOT_PATH = "$"
      PROGRESS_EVERY = 100
      UNREADABLE = Object.new.freeze

      # Compteurs d'un import, au total et par fichier ; un élément en erreur compte une fois, quel que soit son nombre
      # d'erreurs. Sans fichier (génération des classes, ADR-0056), seuls les totaux avancent.
      class Tally
        attr_reader :errors, :details

        def initialize(file_count = 0)
          @imported = 0
          @skipped = 0
          @failed = 0
          @errors = []
          @details = {}
          @per_file = Array.new(file_count) { { imported: 0, skipped: 0, errors: 0 } }
        end

        def counts
          { total_count: @imported + @skipped + @failed, imported_count: @imported, skipped_count: @skipped, error_count: @failed }
        end

        def file_counts(index) = @per_file.fetch(index)

        # items : les éléments écrits (Tracked), pour compter chacun dans son fichier.
        def add(written, items = [])
          @imported += written.fetch(:imported)
          items.each { |item| per_file(item.file_index, :imported) }
          @details.merge!(written.fetch(:details)) { |_key, current, added| current + added }
          nil
        end

        def skip(file_index = nil)
          @skipped += 1
          per_file(file_index, :skipped)
        end

        def invalid(errors, file_index = nil)
          @failed += 1
          @errors.concat(errors)
          per_file(file_index, :errors)
        end

        # Erreurs d'un fichier refusé : notées au rapport, sans élément compté.
        def note(errors) = @errors.concat(errors)

        private

        def per_file(file_index, counter)
          @per_file[file_index][counter] += 1 unless file_index.nil?
          nil
        end
      end

      # Un fichier de l'envoi : son nom d'affichage, sa taille, et soit son document lu (avec sa cible et ses erreurs de
      # schéma par élément), soit les erreurs qui le refusent.
      Source = Struct.new(:index, :name, :byte_size, :document, :rejection, :target, :schema_errors, keyword_init: true) do
        def readable? = rejection.nil?
      end

      # Un élément validé et son fichier, que le moteur suit jusqu'à l'écriture.
      Tracked = Data.define(:item, :file_index)

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

        @tally = Tally.new(0)
        @sources = []
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

        @sources = read_sources(report, kind)
        @tally = Tally.new(@sources.size)
        return reject(report, @sources.flat_map(&:rejection)) if @sources.none?(&:readable?)

        @reports.advance(id: report.id, status: "validating", processed_count: 0, format_version: kind.version)
        validate_documents(report, kind)
      end

      # Chaque fichier est lu, puis contrôlé : JSON, enveloppe, schéma de sa racine, cible. Un fichier en défaut est
      # refusé seul ; ses éléments ne sont pas comptés (ADR-0068).
      def read_sources(report, kind)
        files = @files.read(report_id: report.id)
        names = report.files.map(&:name)
        @multiple = files.size > 1
        files.each_with_index.map do |file, index|
          source = Source.new(index:, name: names[index] || file.name, byte_size: file.content.bytesize)
          check(source, parse(file.content), kind)
          source
        end
      end

      def check(source, document, kind)
        return source.rejection = [ error(source, ROOT_PATH, "json_invalid") ] if document.equal?(UNREADABLE)

        blocking = envelope_errors(source, document, kind)
        return source.rejection = blocking if blocking.any?

        source.document = document
        schema_errors = @schema.validate(format: kind.format, version: kind.version, document:)
                               .map { |schema_error| schema_error.with(file: file_name(source)) }
                               .group_by { |schema_error| root_index(schema_error.path, kind) }
        return source.rejection = schema_errors[nil] if schema_errors.key?(nil)

        target = @adapter.resolve_target(document:)
        if target.failure?
          return source.rejection = [ error(source, kind.target_key || ROOT_PATH, "unknown_target", value: document[kind.target_key]) ]
        end

        source.target = target.value
        source.schema_errors = schema_errors
      end

      def root_index(path, kind) = path[/\A#{Regexp.escape(kind.roots_key)}\[(\d+)\]/, 1]&.to_i

      def validate_documents(report, kind)
        readable = @sources.select(&:readable?)
        count = readable.sum { |source| source.document.fetch(kind.roots_key, []).size }
        if count > kind.max_roots
          return reject(report, [ error(nil, kind.roots_key, "too_many_roots", max: kind.max_roots, count:) ])
        end

        context = @adapter.prepare(target: readable.first.target)
        @tally.note(@sources.reject(&:readable?).flat_map(&:rejection))
        write(report, cross_file_duplicates(validate_roots(report, kind, readable, context)))
        complete(report)
      end

      def parse(raw)
        JSON.parse(raw)
      rescue JSON::ParserError
        UNREADABLE
      end

      # Le format reçu, s'il est un texte, permet à l'écran de nommer l'import auquel le fichier appartient.
      def format_mismatch(source, document, kind)
        received = document["format"] if document.is_a?(Hash)
        return error(source, "format", "format_mismatch", expected: kind.format) unless received.is_a?(String)

        error(source, "format", "format_mismatch", expected: kind.format, received:)
      end

      def envelope_errors(source, document, kind)
        return [ format_mismatch(source, document, kind) ] unless document.is_a?(Hash) && document["format"] == kind.format
        return [ error(source, "version", "version_unsupported", expected: kind.version) ] unless document["version"] == kind.version

        []
      end

      # Tout l'envoi est validé avant la moindre écriture. Un doublon de la base, ou d'un élément plus haut dans le même
      # fichier, est ignoré ; la progression compte les éléments de tous les fichiers.
      def validate_roots(report, kind, readable, context)
        processed = 0
        readable.flat_map do |source|
          seen = Set.new
          source.document.fetch(kind.roots_key, []).each_with_index.filter_map do |root, index|
            item = verdict(source, root, "#{kind.roots_key}[#{index}]", source.schema_errors[index], context)
            progress(report, "validating", processed += 1)
            keep(Tracked.new(item:, file_index: source.index), context, seen)
          end
        end
      end

      # Une erreur de schéma dispense l'adaptateur de valider un élément mal formé.
      def verdict(source, root, path, schema_errors, context)
        return Entities::Catalog::ImportItem.new(path:, errors: schema_errors) if schema_errors

        item = @adapter.validate_root(root:, path:, context:)
        return item unless @multiple

        item.with(errors: item.errors.map { |item_error| item_error.with(file: source.name) })
      end

      def keep(tracked, context, seen)
        item = tracked.item
        return @tally.invalid(item.errors, tracked.file_index) unless item.valid?
        return @tally.skip(tracked.file_index) if context.existing_keys.include?(item.key) || !seen.add?(item.key)

        tracked
      end

      # Le même élément dans deux fichiers d'un envoi : sans doute deux versions ; aucun n'est écrit (ADR-0068).
      def cross_file_duplicates(tracked)
        files_by_key = tracked.group_by { |entry| entry.item.key }.transform_values { |entries| entries.map(&:file_index).uniq }
        tracked.reject do |entry|
          files = files_by_key.fetch(entry.item.key)
          next false if files.one?

          other = @sources.fetch(files.find { it != entry.file_index }).name
          @tally.invalid([ error(@sources.fetch(entry.file_index), entry.item.path, "duplicate_in_files", other:) ], entry.file_index)
          true
        end
      end

      # Par lots de BATCH_SIZE ; un lot refusé est rejoué élément par élément, chacun entier ou pas du tout.
      def write(report, tracked)
        @reports.advance(id: report.id, status: "importing", processed_count: 0)
        at = @clock.now
        done = 0
        tracked.each_slice(Entities::Catalog::ImportKind::BATCH_SIZE) do |batch|
          written = @transaction.attempt { @adapter.write(items: batch.map(&:item), author_id: report.imported_by_id, at:) }
          if written.success?
            @tally.add(written.value, batch)
          else
            batch.each { |entry| write_one(report, entry, at) }
          end
          @reports.advance(id: report.id, status: "importing", processed_count: done += batch.size)
        end
      end

      def write_one(report, entry, at)
        written = @transaction.attempt { @adapter.write(items: [ entry.item ], author_id: report.imported_by_id, at:) }
        return @tally.add(written.value, [ entry ]) if written.success?

        @tally.invalid([ error(@sources.fetch(entry.file_index), entry.item.path, "write_failed") ], entry.file_index)
      end

      def progress(report, status, processed_count)
        @reports.advance(id: report.id, status:, processed_count:) if (processed_count % PROGRESS_EVERY).zero?
      end

      def complete(report)
        finish(report.id, "completed", @tally.errors)
        audit(report, "completed")
        Shared::Result.success(@reports.find(id: report.id))
      end

      # Rejet de tout l'envoi : aucune écriture, aucun élément compté.
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

      # Au-delà de MAX_ERRORS erreurs, seul error_count avance. Le bilan des fichiers n'est écrit que s'ils ont été lus.
      def finish(report_id, status, errors)
        @reports.finish(id: report_id, status:, counts: @tally.counts, details: @tally.details,
                        errors: errors.first(Entities::Catalog::ImportKind::MAX_ERRORS), at: @clock.now, files: file_reports)
      end

      def file_reports
        return if @sources.empty?

        @sources.map do |source|
          reason = source.rejection&.first&.with(path: ROOT_PATH, file: nil)
          Entities::Catalog::ImportFileReport.new(name: source.name, byte_size: source.byte_size,
                                                  status: source.readable? ? "read" : "rejected", reason:,
                                                  **(source.readable? ? @tally.file_counts(source.index) : {}))
        end
      end

      def audit(report, status)
        @audit_log.record(action: "import.run", actor_id: report.imported_by_id, at: @clock.now, subject_type: "ImportReport",
                          subject_id: report.id, metadata: { kind: report.kind, status:, **@tally.counts })
      end

      # L'erreur nomme son fichier dès que l'envoi en compte plusieurs.
      def error(source, path, code, **params)
        Entities::Catalog::ImportError.new(path:, code:, params:, file: source && file_name(source))
      end

      def file_name(source) = (source.name if @multiple)
    end
  end
end
