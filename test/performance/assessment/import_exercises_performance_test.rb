require "test_helper"

# ADR-0039 §7, TR-28: a file at the ceiling, 10 000 exercises (5 questions, 4 answers each) in one essential, runs
# through the complete RunImport on PostgreSQL in under 120 s. Skipped without PERF=1 (out of CI, played before
# acceptance). The rows written, the time and the peak memory are logged.
class Assessment::ImportExercisesPerformanceTest < ActiveSupport::TestCase
  BUDGET_SECONDS = 120
  EXERCISES = 10_000

  setup do
    skip "test de performance : lancez-le avec PERF=1" unless ENV["PERF"] == "1"
    @essential = create_essential
  end

  def peak_memory_mb
    status = Pathname("/proc/self/status")
    return "n/d" unless status.exist?

    status.read[/VmHWM:\s+(\d+)/, 1].to_i / 1024
  end

  test "10 000 exercises and their questions are imported in under two minutes" do
    report = create_import_report(kind: "exercises")
    document = exercises_document(essential: @essential.slug, exercises: EXERCISES, questions: 5, answers: 4)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, filename: "exercices.json", io: StringIO.new(document.to_json))

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Assessment::ImportExercisesJob.perform_now(report.id)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    report.reload
    counts = [ Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)
    puts format("\n[PERF] import de %d exercices, %d questions, %d propositions en %.1f s, mémoire max du processus %s Mo",
                *counts, elapsed, peak_memory_mb)
    assert_equal [ "completed", EXERCISES, 0 ], report.values_at(:status, :imported_count, :error_count)
    assert_equal [ EXERCISES, EXERCISES * 5, EXERCISES * 20 ], counts
    assert_equal (1..EXERCISES).to_a, @essential.exercises.order(:position).pluck(:position)
    assert_operator elapsed, :<, BUDGET_SECONDS
  end
end
