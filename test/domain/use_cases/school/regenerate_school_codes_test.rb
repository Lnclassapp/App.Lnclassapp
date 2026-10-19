require "test_helper"
require_relative "../../../support/domain/fake_regeneration"

# ADR-0096 §4.3, RM-02, RM-05, RM-10, RM-11, RM-14, RM-21, RM-24: the mass regeneration of the school codes, on simulated
# ports — batches, « already changed », the guard of the write, collision and replay, right withdrawn, resume, second run.
module UseCases
  module School
    class RegenerateSchoolCodesTest < ActiveSupport::TestCase
      Fake = FakeRegeneration
      LAUNCH = Fake::LAUNCH

      # The schools of the selection; the UPDATE writes only the rows unchanged since the launch, and a code « already
      # taken » (collisions: id → how many writes refuse it) raises before anything is written, as the unique index does.
      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :codes, :batches, :writes, :taken_reads

        def initialize(candidates, collisions: {}, changed_meanwhile: [], other_refusals: [])
          @candidates = candidates
          @collisions = collisions.dup
          @other_refusals = other_refusals
          @taken_reads = 0
          @changed_meanwhile = changed_meanwhile
          @codes = {}
          @batches = []
          @writes = 0
        end

        def taken_school_codes
          @taken_reads += 1
          Set["aaaaaa"]
        end

        def code_regeneration_batch(selection:, created_before:, after_id:, limit:)
          @batches << [ selection.to_h, created_before, after_id, limit ]
          @candidates.select { it.id > after_id }.first(limit)
        end

        def replace_school_codes(rows:, at:, unchanged_since:)
          @writes += 1
          raise FakeTransaction::OtherRefusal if rows.any? { @other_refusals.include?(it[:id]) }

          refused = rows.find { (@collisions[it[:id]] || 0).positive? }
          if refused
            @collisions[refused[:id]] -= 1
            raise FakeTransaction::Refused
          end

          rows.reject { @changed_meanwhile.include?(it[:id]) }.each { @codes[it[:id]] = [ it[:school_code], at, unchanged_since ] }.map { it[:id] }
        end
      end

      setup do
        @reports = Fake::Reports.new(kind: "school_codes")
        @audit = Fake::AuditLog.new
        @transaction = FakeTransaction.new
      end

      def regenerate(candidates, actor: Fake::ADMIN, batch_size: 200, **)
        @schools = FakeSchools.new(candidates, **)
        RegenerateSchoolCodes.new(schools: @schools, reports: @reports, users: Fake::Users.new(actor), audit_log: @audit,
                                  transaction: @transaction, policy: Policies::School::RegenerateCodesInBulkPolicy.new,
                                  clock: Fake::Clock.new(LAUNCH + 1.minute), batch_size:)
                             .call(report_id: 1)
      end

      def schools(count) = Array.new(count) { Fake.candidate(it + 1, "Lycée #{it + 1}") }

      test "RM-02: every school of the selection gets a new valid and distinct code, batch by batch, and the report counts them" do
        result = regenerate(schools(5), batch_size: 2)

        assert result.success?
        codes = @schools.codes.values.map(&:first)
        assert_equal [ 1, 2, 3, 4, 5 ], @schools.codes.keys
        assert codes.all? { Entities::School::SchoolCode.valid?(it) }
        assert_equal 5, codes.uniq.size
        refute_includes codes, "aaaaaa"
        assert_equal [ [ LAUNCH + 1.minute, LAUNCH ] ], @schools.codes.values.map { it.drop(1) }.uniq
        assert_equal [ 0, 2, 4, 5 ], @reports.advances
        assert_equal [ 0, 2, 4, 5 ], @schools.batches.map { it[2] }
        assert_equal [ [ { "drena" => "abidjan-1" }, LAUNCH, 0, 2 ] ], @schools.batches.first(1)
        assert_equal({ status: "completed", counts: { total_count: 5, imported_count: 5, skipped_count: 0, error_count: 0 },
                       details: { "selection" => { "drena" => "abidjan-1" }, "expected_count" => 3 }, errors: [], error_params: [] }, @reports.finished)
      end

      test "RM-02: the codes already taken are read once and given to every draw, which completes them" do
        draws = []
        original = Entities::School::SchoolCode.method(:generate_unique)
        spy = lambda { |**options|
          before = options[:taken].dup
          original.call(**options).tap { draws << [ options[:count], before ] }
        }

        stub_method(Entities::School::SchoolCode, :generate_unique, spy) { regenerate(schools(3), batch_size: 2) }

        assert_equal 1, @schools.taken_reads
        assert_equal [ 2, 1 ], draws.map(&:first)
        assert_equal [ Set["aaaaaa"], 3 ], [ draws.first.last, draws.last.last.size ]
      end

      test "RM-05, RM-12: one audit line per school, with the report and never the code; then one import.run" do
        regenerate(schools(2))

        assert_equal [ { action: "school.changed", actor_id: 7, at: LAUNCH + 1.minute, subject_type: "School", subject_id: 1,
                         metadata: { change: "code_regenerated", public_id: "p1", report_public_id: "rapport1" } } ], @audit.many.first(1)
        assert_equal 2, @audit.many.size
        refute(@audit.many.any? { |entry| @schools.codes.values.map(&:first).any? { entry.to_s.include?(it) } })
        assert_equal [ [ "import.run", { kind: "school_codes", status: "completed", total_count: 2, imported_count: 2, skipped_count: 0,
                                         error_count: 0 } ] ], @audit.events.map { [ it[:action], it[:metadata] ] }
      end

      test "RM-10: a school changed since the launch is counted « already changed » without being written, an older change is" do
        candidates = [ Fake.candidate(1, "A", rotated_at: LAUNCH), Fake.candidate(2, "B", rotated_at: LAUNCH - 1.day), Fake.candidate(3, "C") ]

        regenerate(candidates)

        assert_equal [ 2, 3 ], @schools.codes.keys
        assert_equal({ total_count: 3, imported_count: 2, skipped_count: 1, error_count: 0 }, @reports.finished[:counts])
      end

      test "RM-21: a batch whose every school changed since the launch writes nothing, not even an empty statement" do
        regenerate([ Fake.candidate(1, "A", rotated_at: LAUNCH), Fake.candidate(2, "B", rotated_at: LAUNCH + 1.second) ])

        assert_equal 0, @schools.writes
        assert_empty @audit.many
        assert_equal({ total_count: 2, imported_count: 0, skipped_count: 2, error_count: 0 }, @reports.finished[:counts])
      end

      test "RM-10: a school changed between the read and the write is left by the guard of the UPDATE, and counted already changed" do
        regenerate(schools(3), changed_meanwhile: [ 2 ])

        assert_equal [ 1, 3 ], @schools.codes.keys
        assert_equal [ 1, 3 ], @audit.many.map { it[:subject_id] }
        assert_equal({ total_count: 3, imported_count: 2, skipped_count: 1, error_count: 0 }, @reports.finished[:counts])
      end

      test "RM-11, RM-24: a batch refused on a taken code is replayed school by school; five refusals put one in error, by its name" do
        regenerate(schools(3), collisions: { 2 => 1, 3 => 5 })

        assert_equal [ 1, 2 ], @schools.codes.keys.sort
        assert_equal({ total_count: 3, imported_count: 2, skipped_count: 0, error_count: 1 }, @reports.finished[:counts])
        assert_equal [ [ "Lycée 3", "write_failed" ] ], @reports.finished[:errors]
        assert_equal 1 + 1 + 1 + 5, @schools.writes
        assert_equal [ 1, 2 ], @audit.many.map { it[:subject_id] }.sort
      end

      test "a refusal that is not a collision is tried once, put in error with its exception class, and logged without any code" do
        warnings = []

        stub_method(Rails.logger, :warn, ->(message) { warnings << message }) do
          regenerate(schools(3), other_refusals: [ 2 ])
        end

        assert_equal [ 1, 3 ], @schools.codes.keys.sort
        assert_equal 1 + 1 + 1 + 1, @schools.writes
        assert_equal({ total_count: 3, imported_count: 2, skipped_count: 0, error_count: 1 }, @reports.finished[:counts])
        assert_equal [ [ "Lycée 2", "write_failed" ] ], @reports.finished[:errors]
        assert_equal [ { exception: "FakeTransaction::OtherRefusal" } ], @reports.finished[:error_params]
        assert_equal 1, warnings.size
        assert_match(/rapport1.*Lycée 2.*FakeTransaction::OtherRefusal/, warnings.first)
        refute(warnings.any? { |message| @schools.codes.values.map(&:first).any? { message.include?(it) } })
      end

      test "the right withdrawn before the start fails the report with its reason, without writing anything" do
        result = regenerate(schools(2), actor: Fake::FIELD)

        assert_equal :forbidden, result.code
        assert_equal "failed", @reports.finished[:status]
        assert_equal [ [ "$", "forbidden" ] ], @reports.finished[:errors]
        assert_empty @schools.codes
        assert_empty @schools.batches
      end

      test "an anonymized author has no actor any more: the report fails with its reason, nothing is written" do
        result = regenerate(schools(2), actor: nil)

        assert_equal :forbidden, result.code
        assert_equal [ "failed", [ [ "$", "forbidden" ] ] ], @reports.finished.values_at(:status, :errors)
        assert_empty @schools.codes
      end

      test "a report already failed as stale when the job starts is not run at all" do
        @reports = Fake::Reports.new(kind: "school_codes", advance_refused_after: 0)

        result = regenerate(schools(2))

        assert_equal [ :conflict, { base: [ :no_longer_running ] } ], [ result.code, result.errors ]
        assert_empty @schools.batches
        assert_nil @reports.finished
      end

      test "a report no longer running (failed as stale meanwhile) stops the run at the first batch it cannot advance" do
        @reports = Fake::Reports.new(kind: "school_codes", advance_refused_after: 2)

        result = regenerate(schools(5), batch_size: 2)

        assert_equal [ :conflict, { base: [ :no_longer_running ] } ], [ result.code, result.errors ]
        assert_equal [ 1, 2, 3, 4 ], @schools.codes.keys
        assert_nil @reports.finished
        assert_empty @audit.events
      end

      test "a report failed as stale just before the end is not closed nor audited as a run" do
        @reports = Fake::Reports.new(kind: "school_codes", finish_refused: true)

        result = regenerate(schools(2))

        assert_equal [ :conflict, { base: [ :no_longer_running ] } ], [ result.code, result.errors ]
        assert_empty @audit.events
      end

      test "RM-21: a finished report run again changes nothing" do
        @reports = Fake::Reports.new(kind: "school_codes", status: "completed")

        assert_equal [ :conflict, { base: [ :already_claimed ] } ], regenerate(schools(2)).then { [ it.code, it.errors ] }
        assert_empty @schools.codes
        assert_empty @schools.batches
        assert_nil @reports.finished
      end

      test "RM-21: a report left importing by a dead job is resumed, and what it changed is counted already changed" do
        @reports = Fake::Reports.new(kind: "school_codes", status: "importing")
        candidates = [ Fake.candidate(1, "A", rotated_at: LAUNCH + 10.seconds), Fake.candidate(2, "B") ]

        assert regenerate(candidates).success?
        assert_equal [ 2 ], @schools.codes.keys
        assert_equal({ total_count: 2, imported_count: 1, skipped_count: 1, error_count: 0 }, @reports.finished[:counts])
      end

      test "an unexpected failure fails the report, then reaches the job" do
        @reports = Fake::Reports.new(kind: "school_codes")
        schools = FakeSchools.new([])
        def schools.code_regeneration_batch(**) = raise("base indisponible")

        assert_raises(RuntimeError) do
          RegenerateSchoolCodes.new(schools:, reports: @reports, users: Fake::Users.new(Fake::ADMIN), audit_log: @audit,
                                    transaction: @transaction, policy: Policies::School::RegenerateCodesInBulkPolicy.new,
                                    clock: Fake::Clock.new(LAUNCH)).call(report_id: 1)
        end
        assert_equal "failed", @reports.finished[:status]
      end

      test "an empty selection completes with nothing counted" do
        assert regenerate([]).success?
        assert_equal({ total_count: 0, imported_count: 0, skipped_count: 0, error_count: 0 }, @reports.finished[:counts])
      end
    end
  end
end
