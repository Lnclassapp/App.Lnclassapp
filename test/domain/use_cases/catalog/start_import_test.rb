require "test_helper"

module UseCases
  module Catalog
    class StartImportTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Report = Entities::Catalog::ImportReport

      # Un seul import en cours par type, comme l'index partiel ; fail_stale libère un rapport bloqué.
      class FakeReports
        include Ports::Catalog::ImportReportRepositoryPort

        attr_reader :reports, :stale_before, :created_files

        def initialize(reports = [])
          @reports = reports
        end

        def fail_stale(kind:, before:, at:)
          @stale_before = before
          stale = @reports.select { it.kind == kind && %w[validating importing].include?(it.status) && it.started_at < before }
          @reports = @reports.map { stale.include?(it) ? it.with(status: "failed", finished_at: at) : it }
          stale.size
        end

        def create(kind:, checksum_sha256:, imported_by_id:, at:, files: [])
          return Shared::Result.failure(:conflict, errors: { kind: [ :already_running ] }) if @reports.any? { it.kind == kind && it.running? }

          @created_files = files
          report = StartImportTest.report(id: @reports.size + 1, kind:, status: "queued", imported_by_id:, started_at: nil)
          @reports << report
          Shared::Result.success(report)
        end
      end

      class FakeFiles
        include Ports::Catalog::ImportFileStorePort

        attr_reader :attached

        def attach(report_id:, files:) = (@attached = [ report_id, *files.flat_map { [ it.io.read, it.filename ] } ]) && true
      end

      class FakeQueue
        include Ports::Catalog::ImportQueuePort

        attr_reader :enqueued

        def enqueue(kind:, report_id:) = (@enqueued = [ kind, report_id ]) && true
      end

      def self.report(id:, kind:, status:, imported_by_id: 9, started_at: NOW)
        Report.new(id:, public_id: "rapport#{id}", kind:, status:, format_version: nil, total_count: 0, imported_count: 0,
                   skipped_count: 0, error_count: 0, processed_count: 0, details: {}, import_errors: [], imported_by_id:,
                   started_at:, finished_at: nil)
      end

      setup do
        @reports = FakeReports.new
        @files = FakeFiles.new
        @queue = FakeQueue.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def start(actor: @team, content: %({"format":"lnclass.schools"}), kind: "schools", filename: "ecoles.json", files: nil)
        files ||= [ Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(content), filename:) ]
        dto = Dtos::Catalog::ImportUploadInput.new(kind:, files:)
        StartImport.new(reports: @reports, files: @files, queue: @queue, transaction: @transaction, clock: Clock.new(NOW))
                   .call(actor:, dto:)
      end

      test "crée le rapport queued, stocke le fichier dans la transaction, puis met le job du type en file" do
        result = start

        assert result.success?
        assert_equal [ "queued", "schools", 7 ], [ result.value.status, result.value.kind, result.value.imported_by_id ]
        assert_equal [ 1, %({"format":"lnclass.schools"}), "ecoles.json" ], @files.attached
        assert_equal [ "schools", 1 ], @queue.enqueued
        assert_equal 1, @transaction.calls
      end

      # ADR-0068 : chaque fichier est noté au rapport, avec son nom d'affichage et sa taille, puis stocké dans l'ordre d'envoi.
      test "plusieurs fichiers : un rapport, leurs noms distincts et leurs tailles, stockés dans l'ordre d'envoi" do
        files = [ [ "cours.json", "{}" ], [ "cours.json", "[1]" ] ].map do |filename, json|
          Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(json), filename:)
        end

        assert start(kind: "course_tree", files:).success?
        assert_equal [ [ "cours.json", 2, "pending" ], [ "cours.json (2)", 3, "pending" ] ], @reports.created_files.map { [ it.name, it.byte_size, it.status ] }
        assert_equal [ 1, "{}", "cours.json", "[1]", "cours.json" ], @files.attached
      end

      test "un acteur hors de l'équipe est refusé, sans rien créer" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, start(actor: teacher).code
        assert_equal :forbidden, start(actor: nil).code
        assert_empty @reports.reports
      end

      test "20 Mo et un octet donnent :invalid avec too_large, sans rien créer" do
        result = start(content: "x" * (Entities::Catalog::ImportKind::MAX_BYTES + 1))

        assert_equal :invalid, result.code
        assert_equal [ "« ecoles.json » dépasse 20 Mo." ], result.errors[:files]
        assert_empty @reports.reports
        assert_nil @queue.enqueued
      end

      test "un second import du même type en cours donne :conflict, sans fichier ni job" do
        @reports = FakeReports.new([ self.class.report(id: 1, kind: "schools", status: "importing", started_at: NOW - 5 * 60) ])

        result = start

        assert_equal({ kind: [ :already_running ] }, result.errors)
        assert_nil @files.attached
        assert_nil @queue.enqueued
        assert start(kind: "course_tree").success?
      end

      test "un rapport bloqué depuis 11 minutes passe failed et libère le type : la limite est de 10 minutes" do
        @reports = FakeReports.new([ self.class.report(id: 1, kind: "schools", status: "importing", started_at: NOW - 11 * 60) ])

        assert start.success?
        assert_equal [ "failed", NOW ], @reports.reports.first.to_h.values_at(:status, :finished_at)
        assert_equal NOW - (10 * 60), @reports.stale_before
      end
    end
  end
end
