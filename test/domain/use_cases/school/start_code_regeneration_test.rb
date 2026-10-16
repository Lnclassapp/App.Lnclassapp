require "test_helper"

# ADR-0096 §4.2, RM-01, RM-06 to RM-09, RM-15, RM-16, RM-19, RM-22: launching a mass regeneration counts the selection,
# checks the typed number outside one DRENA or one school, creates its report without a file nor code, and queues its job.
module UseCases
  module School
    class StartCodeRegenerationTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 16, 12)
      Clock = Data.define(:now)
      Selection = Dtos::School::SchoolSelection

      class FakeReports
        include Ports::Catalog::ImportReportRepositoryPort

        attr_reader :created, :stale

        def initialize(running: [])
          @running = running
        end

        def fail_stale(kind:, before:, at:)
          @stale = [ kind, before, at ]
          0
        end

        def create(kind:, checksum_sha256:, imported_by_id:, at:, files: [], details: {})
          return Shared::Result.failure(:conflict, errors: { kind: [ :already_running ] }) if @running.include?(kind)

          @created = { kind:, checksum_sha256:, imported_by_id:, at:, files:, details: }
          Shared::Result.success(Entities::Catalog::ImportReport.new(
            id: 41, public_id: "rapport41", kind:, status: "queued", format_version: nil, total_count: 0, imported_count: 0,
            skipped_count: 0, error_count: 0, processed_count: 0, details:, import_errors: [], imported_by_id:,
            started_at: nil, finished_at: nil, created_at: at
          ))
        end
      end

      class FakeQueue
        include Ports::Catalog::ImportQueuePort

        attr_reader :enqueued

        def enqueue(kind:, report_id:) = (@enqueued = [ kind, report_id ]) && true
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :asked

        def initialize(count) = @count = count

        def count_for_code_regeneration(selection:, created_before:)
          @asked = [ selection, created_before ]
          @count
        end
      end

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :asked

        def initialize(count) = @count = count

        def count_for_link_regeneration(selection:, school_year:, created_before:)
          @asked = [ selection, school_year, created_before ]
          @count
        end
      end

      setup do
        @reports = FakeReports.new
        @queue = FakeQueue.new
        @schools = FakeSchools.new(214)
        @classrooms = FakeClassrooms.new(3120)
        @admin = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      end

      def start(actor: @admin, target: "school_codes", selection: { drena: "abidjan-1" }, typed_count: nil, current_year_only: "1")
        dto = Dtos::School::CodeRegenerationInput.new(target:, selection:, typed_count:, current_year_only:)
        StartCodeRegeneration.new(reports: @reports, queue: @queue, schools: @schools, classrooms: @classrooms,
                                  policy: Policies::School::RegenerateCodesInBulkPolicy.new, clock: Clock.new(NOW))
                             .call(actor:, dto:)
      end

      test "RM-01: one DRENA, no number to type: a report without a file keeps the selection and the count, then its job is queued" do
        result = start

        assert result.success?
        assert_equal({ kind: "school_codes", checksum_sha256: nil, imported_by_id: 7, at: NOW, files: [],
                       details: { "selection" => { "drena" => "abidjan-1", "school_year" => nil }, "expected_count" => 214 } },
                     @reports.created)
        assert_equal [ "school_codes", 41 ], @queue.enqueued
        assert_equal [ Selection.from({ drena: "abidjan-1" }), NOW ], @schools.asked
        assert_equal [ "school_codes", NOW - UseCases::Catalog::StartImport::STALE_AFTER, NOW ], @reports.stale
      end

      test "RM-15, RM-19: the links of the classrooms count the active classrooms of the current year by default" do
        assert start(target: "classroom_links").success?

        assert_equal [ Selection.from({ drena: "abidjan-1" }), "2026-2027", NOW ], @classrooms.asked
        assert_equal({ "selection" => { "drena" => "abidjan-1", "school_year" => "2026-2027" }, "expected_count" => 3120 },
                     @reports.created[:details])
        assert_equal [ "classroom_links", 41 ], @queue.enqueued
      end

      test "RM-19: without the current year only, every year is counted" do
        start(target: "classroom_links", current_year_only: "0")

        assert_nil @classrooms.asked[1]
        assert_nil @reports.created[:details]["selection"]["school_year"]
      end

      test "RM-16: one school, from its card, needs no number either" do
        assert start(target: "classroom_links", selection: { school: "lycee42" }).success?

        assert_equal({ "school" => "lycee42", "school_year" => "2026-2027" }, @reports.created[:details]["selection"])
      end

      test "RM-06: outside one DRENA, the typed number must be the count, spaces allowed; nothing is created otherwise" do
        assert_equal [ :invalid, { typed_count: [ :mismatch ] } ],
                     start(selection: { status: "active" }, typed_count: "213").then { [ it.code, it.errors ] }
        assert_equal :invalid, start(selection: {}, typed_count: nil).code
        assert_nil @reports.created
        assert_nil @queue.enqueued

        assert start(selection: {}, typed_count: " 214 ").success?
      end

      test "RM-07: an empty selection is refused before the typed number, and nothing is created" do
        @schools = FakeSchools.new(0)

        result = start(selection: {}, typed_count: "0")

        assert_equal [ :invalid, { base: [ :empty ] } ], [ result.code, result.errors ]
        assert_nil @reports.created
      end

      test "RM-08: a regeneration of the same kind already running gives :conflict, and nothing is queued" do
        @reports = FakeReports.new(running: [ "school_codes" ])

        assert_equal :conflict, start.code
        assert_nil @queue.enqueued
        assert start(target: "classroom_links").success?
      end

      test "RM-09, RM-22: content, field, a direction, a teacher and a visitor are refused, before any count" do
        [ Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "content"),
          Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "field"),
          Entities::Identity::Actor.new(user_id: 3, role: :school_admin, school_id: 1),
          Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1), nil ].each do |actor|
          %w[school_codes classroom_links].each { |target| assert_equal :forbidden, start(actor:, target:).code }
        end
        assert_nil @schools.asked
        assert_nil @classrooms.asked
        assert_nil @reports.stale
      end

      test "an unknown target is invalid, and nothing is read" do
        assert_equal [ :invalid, { target: [ :inclusion ] } ], start(target: "users").then { [ it.code, it.errors ] }
        assert_nil @schools.asked
      end
    end
  end
end
