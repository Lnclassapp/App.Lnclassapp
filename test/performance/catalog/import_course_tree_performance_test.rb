require "test_helper"

# ADR-0039 §7, CA-08, ADR-0116: 200 complete v3 lessons (2 notions with 1 exercise each + 4 problems, 5 questions, 2 answers) run through the
# complete RunImport on PostgreSQL, in under 120 s. Skipped without PERF=1 (out of CI, played before acceptance).
# The rows written, the time and the peak memory are logged.
class Catalog::ImportCourseTreePerformanceTest < ActiveSupport::TestCase
  BUDGET_SECONDS = 120
  COURSES = 200

  setup do
    skip "test de performance : lancez-le avec PERF=1" unless ENV["PERF"] == "1"
    seed_referential
  end

  def peak_memory_mb
    status = Pathname("/proc/self/status")
    return "n/d" unless status.exist?

    status.read[/VmHWM:\s+(\d+)/, 1].to_i / 1024
  end

  test "200 complete courses and their descendants are imported in under two minutes" do
    course = revision_sheet_document.fetch("courses").first
    document = { "format" => "lnclass.course-tree", "version" => 3,
                 "courses" => Array.new(COURSES) { course.merge("name" => "Racines carrées #{it + 1}") } }
    report = create_import_report(kind: "course_tree")
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(filename: "cours.json",
                                                      io: StringIO.new(document.to_json)) ])

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Catalog::ImportCourseTreeJob.perform_now(report.id)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    report.reload
    counts = [ Orm::Course, Orm::Essential, Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)
    puts format("\n[PERF] import de %d cours : %d notions, %d exercices, %d questions, %d propositions en %.1f s, mémoire max du processus %s Mo",
                *counts, elapsed, peak_memory_mb)
    assert_equal [ "completed", COURSES, 0 ], report.values_at(:status, :imported_count, :error_count)
    assert_equal [ COURSES, COURSES * 2, COURSES * 6, COURSES * 30, COURSES * 60 ], counts
    assert_equal COURSES * 60, report.details["answers_created"]
    assert_operator elapsed, :<, BUDGET_SECONDS
  end
end
