require "test_helper"

# ADR-0039 §7, SC-08: 500 schools run through the complete RunImport on PostgreSQL, in under 120 s. Skipped without
# PERF=1 (out of CI, played before acceptance). The classrooms written, the time and the peak memory are logged.
# The plan mix (44 % collèges; public, private and mixed) gives some 18 000 classrooms; 500 public lycées give the
# 38 500 of the worst case, above the 35 000 the ADR estimates.
class School::ImportSchoolsPerformanceTest < ActiveSupport::TestCase
  BUDGET_SECONDS = 120
  SCHOOLS = 500

  setup do
    skip "test de performance : lancez-le avec PERF=1" unless ENV["PERF"] == "1"
    seed_referential
    create_drena(name: "Abidjan 2")
  end

  def peak_memory_mb
    status = Pathname("/proc/self/status")
    return "n/d" unless status.exist?

    status.read[/VmHWM:\s+(\d+)/, 1].to_i / 1024
  end

  def import(document)
    report = create_import_report(kind: "schools")
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(filename: "ecoles.json", io: StringIO.new(document.to_json)) ])

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    School::ImportSchoolsJob.perform_now(report.id)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    report.reload
    classrooms = Orm::Classroom.count
    puts format("\n[PERF] import de %d établissements : %d classes en %.1f s, mémoire max du processus %s Mo",
                SCHOOLS, classrooms, elapsed, peak_memory_mb)
    assert_equal [ "completed", SCHOOLS, 0 ], report.values_at(:status, :imported_count, :error_count)
    assert_equal classrooms, report.details["classrooms_created"]
    assert_equal classrooms, Orm::Classroom.distinct.count(:join_code)
    assert_operator elapsed, :<, BUDGET_SECONDS
    classrooms
  end

  test "500 schools of the plan mix and their classrooms are imported in under two minutes, every join code distinct" do
    import(schools_document(count: SCHOOLS, drena: "drena-abidjan-2"))
  end

  test "500 public lycées, the worst case, give 38 500 classrooms in under two minutes" do
    assert_equal SCHOOLS * 77, import(schools_document(count: SCHOOLS, drena: "drena-abidjan-2", college_ratio: 0, types: %w[public]))
  end
end
