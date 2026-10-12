require "test_helper"

# ADR-0056, GC-09: 500 schools without classrooms get theirs through the real job on PostgreSQL, in under 60 s.
# Skipped without PERF=1 (out of CI, played before acceptance). PERF_SCHOOLS changes the volume (3 900 for the
# production case); the classrooms written, the time and the peak memory are logged.
class Classroom::GenerateMissingClassroomsPerformanceTest < ActiveSupport::TestCase
  BUDGET_SECONDS = 60
  SCHOOLS = Integer(ENV.fetch("PERF_SCHOOLS", 500))
  COLLEGE_RATIO = 0.44
  TYPES = %w[public private mixed].freeze

  setup do
    skip "test de performance : lancez-le avec PERF=1" unless ENV["PERF"] == "1"
    seed_referential
    @drena = create_drena(name: "Abidjan 2")
  end

  def peak_memory_mb
    status = Pathname("/proc/self/status")
    return "n/d" unless status.exist?

    status.read[/VmHWM:\s+(\d+)/, 1].to_i / 1024
  end

  # Imported before the referential: schools, and not a single classroom.
  def insert_schools(count, types:, college_ratio:)
    colleges = (count * college_ratio).round
    now = Time.current
    codes = Entities::School::SchoolCode.generate_unique(count:, taken: Set.new)
    rows = Array.new(count) do |index|
      { public_id: SecureRandom.base58(14), drena_id: @drena.id, name: "#{index < colleges ? 'Collège' : 'Lycée'} Moderne #{index + 1}",
        school_type: types[index % types.size], cycle: index < colleges ? "first" : "both", status: "active",
        school_code: codes[index], created_at: now, updated_at: now }
    end
    rows.each_slice(1_000) { Orm::School.insert_all!(it) }
  end

  def generate
    report = create_import_report(kind: "classrooms", checksum_sha256: nil)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Classroom::GenerateMissingClassroomsJob.perform_now(report.id)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    report.reload
    classrooms = Orm::Classroom.count
    puts format("\n[PERF] génération pour %d établissements : %d classes en %.1f s, mémoire max du processus %s Mo",
                SCHOOLS, classrooms, elapsed, peak_memory_mb)
    assert_equal [ "completed", SCHOOLS, 0 ], report.values_at(:status, :imported_count, :error_count)
    assert_equal classrooms, report.details["classrooms_created"]
    assert_equal classrooms, Orm::Classroom.distinct.count(:link_token)
    assert_operator elapsed, :<, BUDGET_SECONDS * SCHOOLS / 500.0
    classrooms
  end

  test "500 schools of the plan mix get their classrooms in under a minute, every join code distinct" do
    insert_schools(SCHOOLS, types: TYPES, college_ratio: COLLEGE_RATIO)

    generate
  end

  test "500 public lycées, the worst case, get their 38 500 classrooms in under a minute" do
    insert_schools(SCHOOLS, types: %w[public], college_ratio: 0)

    assert_equal SCHOOLS * 77, generate
  end
end
