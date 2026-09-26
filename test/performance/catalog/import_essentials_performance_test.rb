require "test_helper"

# ADR-0039 §7, CA-15: a file at the ceiling, 2 000 essentials (2 exercises, 10 questions, 4 answers) in one course, runs
# through the complete RunImport on PostgreSQL in under 120 s. Skipped without PERF=1 (out of CI, played before
# acceptance). The rows written, the time and the peak memory are logged.
class Catalog::ImportEssentialsPerformanceTest < ActiveSupport::TestCase
  BUDGET_SECONDS = 120
  ESSENTIALS = Entities::Catalog::ImportKind.fetch("essentials").max_roots

  setup do
    skip "test de performance : lancez-le avec PERF=1" unless ENV["PERF"] == "1"
  end

  def peak_memory_mb
    status = Pathname("/proc/self/status")
    return "n/d" unless status.exist?

    status.read[/VmHWM:\s+(\d+)/, 1].to_i / 1024
  end

  test "2 000 essentials and their exercises are imported in one course in under two minutes" do
    course = create_course
    report = create_import_report(kind: "essentials")
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, filename: "fiches.json",
                                                      io: StringIO.new(essentials_document(course: course.slug, essentials: ESSENTIALS).to_json))

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Catalog::ImportEssentialsJob.perform_now(report.id)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    report.reload
    counts = [ Orm::Essential, Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)
    puts format("\n[PERF] import de %d fiches, %d exercices, %d questions, %d propositions en %.1f s, mémoire max du processus %s Mo",
                *counts, elapsed, peak_memory_mb)
    assert_equal [ "completed", ESSENTIALS, 0 ], report.values_at(:status, :imported_count, :error_count)
    assert_equal [ ESSENTIALS, ESSENTIALS * 2, ESSENTIALS * 20, ESSENTIALS * 80 ], counts
    assert_equal [ 1, ESSENTIALS ], course.essentials.pick(Arel.sql("MIN(position)"), Arel.sql("MAX(position)"))
    assert_equal ESSENTIALS * 80, report.details["answers_created"]
    assert_operator elapsed, :<, BUDGET_SECONDS
  end
end
