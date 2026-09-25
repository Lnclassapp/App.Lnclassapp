require "test_helper"

module UseCases
  module Catalog
    class RunImportTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      ImportError = Entities::Catalog::ImportError

      # Un rapport en mémoire : claim, progression, fin, comme ImportReportRepository.
      class FakeReports
        include Ports::Catalog::ImportReportRepositoryPort

        attr_reader :report, :advances, :finished

        def initialize(status: "queued", imported_by_id: 7)
          @report = Entities::Catalog::ImportReport.new(
            id: 1, public_id: "rapport1", kind: "schools", status:, format_version: nil, total_count: 0, imported_count: 0,
            skipped_count: 0, error_count: 0, processed_count: 0, details: {}, import_errors: [], imported_by_id:,
            started_at: nil, finished_at: nil
          )
          @advances = []
        end

        def claim(id:, at:)
          return false unless @report.status == "queued"

          @report = @report.with(status: "validating", started_at: at)
          true
        end

        def find(id:) = @report

        def advance(id:, status:, processed_count:, format_version: nil)
          @advances << [ status, processed_count, format_version ]
          @report = @report.with(status:, processed_count:, format_version: format_version || @report.format_version)
          true
        end

        def finish(id:, status:, counts:, details:, errors:, at:)
          @finished = { status:, counts:, details:, errors: }
          @report = @report.with(status:, **counts, details:, import_errors: errors, finished_at: at)
          true
        end
      end

      class FakeFiles
        include Ports::Catalog::ImportFileStorePort

        attr_reader :reads

        def initialize(content)
          @content = content
          @reads = 0
        end

        def read(report_id:)
          @reads += 1
          @content
        end
      end

      # Les erreurs de schéma sont programmées : le vrai validateur a son propre test.
      class FakeSchema
        include Ports::Catalog::ImportSchemaPort

        def initialize(errors = [])
          @errors = errors
        end

        def validate(format:, version:, document:) = @errors
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(actor)
          @actor = actor
        end

        def actor_for(user_id:) = @actor
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize
          @entries = []
        end

        def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
          @entries << { action:, actor_id:, subject_type:, subject_id:, metadata: }
          true
        end
      end

      setup do
        @reports = FakeReports.new
        @adapter = FakeImporter.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def run_import(document, schema_errors: [], actor: @team)
        content = document.is_a?(String) ? document : JSON.generate(document)
        @files = FakeFiles.new(content)
        RunImport.new(adapter: @adapter, reports: @reports, files: @files, schema: FakeSchema.new(schema_errors),
                      users: FakeUsers.new(actor), audit_log: @audit, transaction: @transaction, clock: Clock.new(NOW))
                 .call(report_id: 1)
      end

      def schools(*names, drena: "abidjan-2")
        { "format" => "lnclass.schools", "version" => 1, "drena" => drena, "schools" => names.map { { "name" => it } } }
      end

      def error_pairs = @reports.report.import_errors.map { [ it.path, it.code ] }

      test "l'adaptateur factice respecte le contrat des importeurs" do
        context = @adapter.prepare(target: nil)

        assert_importer_contract(FakeImporter, adapter: @adapter, root: { "name" => "Lycée A" }, context:)
      end

      test "un import passe de queued à completed, écrit ses éléments et journalise import.run" do
        result = run_import(schools("Lycée A", "Collège B"))

        assert result.success?
        assert_equal "completed", result.value.status
        assert_equal [ "Lycée A", "Collège B" ], @adapter.written
        assert_equal({ total_count: 2, imported_count: 2, skipped_count: 0, error_count: 0 }, @reports.finished[:counts])
        assert_equal({ "classrooms" => 4 }, @reports.finished[:details])
        assert_equal [ [ "validating", 0, 1 ], [ "importing", 0, nil ], [ "importing", 2, nil ] ], @reports.advances
        assert_equal [ { action: "import.run", actor_id: 7, subject_type: "ImportReport", subject_id: 1,
                         metadata: { kind: "schools", status: "completed", total_count: 2, imported_count: 2, skipped_count: 0,
                                     error_count: 0 } } ], @audit.entries
      end

      test "un fichier mixte donne un rapport exact : 7 importés, 2 en erreur avec leur chemin, 2 doublons" do
        @adapter = FakeImporter.new(existing: [ "Lycée Moderne de Cocody" ])
        names = [ "Lycée A", "Lycée B", "", "Lycée C", "Lycée D", "lycee  moderne de COCODY", "Lycée E", "LYCÉE A",
                  "Lycée F", "Lycée G", "Lycée H" ]
        schema_errors = [ ImportError.new(path: "schools[4].name", code: "schema", params: { keyword: "maxLength" }) ]

        result = run_import(schools(*names), schema_errors:)

        assert_equal "completed", result.value.status
        assert_equal({ total_count: 11, imported_count: 7, skipped_count: 2, error_count: 2 }, @reports.finished[:counts])
        assert_equal [ [ "schools[2].name", "blank" ], [ "schools[4].name", "schema" ] ], error_pairs
        assert_equal [ "Lycée A", "Lycée B", "Lycée C", "Lycée E", "Lycée F", "Lycée G", "Lycée H" ], @adapter.written
      end

      test "chaque motif de rejet en bloc finit rejected, sans aucune écriture" do
        too_many = schools(*Array.new(5_001) { "Lycée #{it}" })
        cases = {
          "json_invalid" => [ "{ pas du JSON", [], "$" ],
          "format_mismatch" => [ schools("Lycée A").merge("format" => "lnclass.course-tree"), [], "format" ],
          "version_unsupported" => [ schools("Lycée A").merge("version" => 2), [], "version" ],
          "schema" => [ schools("Lycée A"), [ ImportError.new(path: "drena", code: "schema", params: { keyword: "type" }) ], "drena" ],
          "unknown_target" => [ schools("Lycée A", drena: "inconnue"), [], "drena" ],
          "too_many_roots" => [ too_many, [], "schools" ]
        }

        cases.each do |code, (document, schema_errors, path)|
          @reports = FakeReports.new
          @audit = FakeAudit.new

          result = run_import(document, schema_errors:)

          assert_equal "rejected", result.value.status, code
          assert_equal [ [ path, code ] ], error_pairs, code
          assert_equal({ total_count: 0, imported_count: 0, skipped_count: 0, error_count: 0 }, @reports.finished[:counts], code)
          assert_equal "rejected", @audit.entries.sole[:metadata][:status], code
        end
        assert_equal 0, @adapter.writes
      end

      test "un document qui n'est pas un objet est rejeté sur son format" do
        run_import([ { "name" => "Lycée A" } ])

        assert_equal [ [ "format", "format_mismatch" ] ], error_pairs
      end

      test "un lot refusé par la base est rejoué élément par élément : un seul élément en write_failed" do
        @adapter = FakeImporter.new(refused: [ "Lycée 42" ])

        run_import(schools(*Array.new(150) { "Lycée #{it}" }))

        assert_equal({ total_count: 150, imported_count: 149, skipped_count: 0, error_count: 1 }, @reports.finished[:counts])
        assert_equal [ [ "schools[42]", "write_failed" ] ], error_pairs
        assert_equal 1 + 100 + 1, @transaction.attempts
        assert_equal [ [ "importing", 100, nil ], [ "importing", 150, nil ] ], @reports.advances.last(2)
      end

      test "1 001 éléments en erreur : 1 000 erreurs gardées, error_count vaut 1 001 ; la progression avance par 100" do
        run_import(schools(*Array.new(1_001, "")))

        assert_equal 1_001, @reports.report.error_count
        assert_equal 1_000, @reports.report.import_errors.size
        assert_equal (1..10).map { [ "validating", it * 100, nil ] }, @reports.advances[1..10]
      end

      test "un rôle retiré depuis le téléversement fait échouer l'import sans lire le fichier" do
        teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)

        result = run_import(schools("Lycée A"), actor: teacher)

        assert_equal :forbidden, result.code
        assert_equal "failed", @reports.report.status
        assert_equal 0, @files.reads
        assert_empty @audit.entries
      end

      test "un rapport déjà pris par un autre job ne fait rien" do
        @reports = FakeReports.new(status: "validating")

        result = run_import(schools("Lycée A"))

        assert_equal :conflict, result.code
        assert_nil @reports.finished
        assert_equal 0, @files.reads
      end

      test "une panne imprévue passe le rapport failed avec ce qui était déjà écrit, puis remonte" do
        @adapter = FakeImporter.new(exploding: [ "Lycée 120" ])

        error = assert_raises(RuntimeError) { run_import(schools(*Array.new(150) { "Lycée #{it}" })) }

        assert_match "Lycée 120", error.message
        assert_equal "failed", @reports.report.status
        assert_equal({ total_count: 100, imported_count: 100, skipped_count: 0, error_count: 0 }, @reports.finished[:counts])
      end

      test "un fichier réel de l'ancienne application, enveloppé, et un document généré puis mélangé s'importent" do
        assert_equal 10, run_import(import_sample("schools_legacy_sample")).value.imported_count

        @reports = FakeReports.new
        @adapter = FakeImporter.new
        run_import(mixed(schools_document(count: 10, drena: "abidjan-2")))

        assert_equal({ total_count: 10, imported_count: 7, skipped_count: 1, error_count: 2 }, @reports.finished[:counts])
      end
    end
  end
end
