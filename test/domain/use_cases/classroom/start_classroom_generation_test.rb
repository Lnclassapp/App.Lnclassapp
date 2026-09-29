require "test_helper"

# ADR-0056, GC-04, GC-08: launching the generation creates its report without a file and queues its job.
module UseCases
  module Classroom
    class StartClassroomGenerationTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)

      class FakeReports
        include Ports::Catalog::ImportReportRepositoryPort

        attr_reader :reports, :created, :stale

        def initialize(reports = [])
          @reports = reports
        end

        def fail_stale(kind:, before:, at:)
          @stale = [ kind, before, at ]
          0
        end

        def create(kind:, checksum_sha256:, imported_by_id:, at:)
          return Shared::Result.failure(:conflict, errors: { kind: [ :already_running ] }) if @reports.any? { it.kind == kind && it.running? }

          @created = { kind:, checksum_sha256:, imported_by_id:, at: }
          report = StartClassroomGenerationTest.report(id: @reports.size + 1, kind:, status: "queued")
          @reports << report
          Shared::Result.success(report)
        end
      end

      class FakeQueue
        include Ports::Catalog::ImportQueuePort

        attr_reader :enqueued

        def enqueue(kind:, report_id:) = (@enqueued = [ kind, report_id ]) && true
      end

      def self.report(id:, kind:, status:)
        Entities::Catalog::ImportReport.new(
          id:, public_id: "rapport#{id}", kind:, status:, format_version: nil, total_count: 0, imported_count: 0,
          skipped_count: 0, error_count: 0, processed_count: 0, details: {}, import_errors: [], imported_by_id: 7,
          started_at: nil, finished_at: nil
        )
      end

      setup do
        @reports = FakeReports.new
        @queue = FakeQueue.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def start(actor: @team)
        StartClassroomGeneration.new(reports: @reports, queue: @queue, policy: Policies::School::ManageSchoolPolicy.new,
                                     clock: Clock.new(NOW)).call(actor:)
      end

      test "creates a queued report without a file, then queues the job of the generation" do
        result = start

        assert result.success?
        assert_equal [ "classrooms", "queued" ], [ result.value.kind, result.value.status ]
        assert_equal({ kind: "classrooms", checksum_sha256: nil, imported_by_id: 7, at: NOW }, @reports.created)
        assert_equal [ "classrooms", 1 ], @queue.enqueued
      end

      test "stale reports of the generation are released first, after 10 minutes as for the imports" do
        start

        assert_equal [ "classrooms", NOW - UseCases::Catalog::StartImport::STALE_AFTER, NOW ], @reports.stale
      end

      test "outside the team, the launch is refused and nothing is created" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, start(actor: teacher).code
        assert_equal :forbidden, start(actor: nil).code
        assert_empty @reports.reports
        assert_nil @queue.enqueued
      end

      test "a generation already running gives :conflict, without a second job" do
        @reports = FakeReports.new([ self.class.report(id: 1, kind: "classrooms", status: "importing") ])

        result = start

        assert_equal :conflict, result.code
        assert_equal({ kind: [ :already_running ] }, result.errors)
        assert_nil @queue.enqueued
      end
    end
  end
end
