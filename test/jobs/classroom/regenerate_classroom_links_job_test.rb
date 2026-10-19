require "test_helper"

# ADR-0096, RM-17 to RM-19, RM-21, RM-23: the job changes the links of the active classrooms of the selection on the real
# repositories; the old links die, the students stay; no token in the report nor in the audit.
class Classroom::RegenerateClassroomLinksJobTest < ActiveJob::TestCase
  setup do
    @school = create_school(name: "Lycée Moderne de Cocody")
    @level = create_level
    @author = create_team_member(second_factor: false)
    @launch = 1.minute.ago.change(usec: 0)
  end

  def classroom(school: @school, **) = create_classroom(school:, level: @level, created_at: @launch - 1.day, **)

  def launch(school_year: current_school_year)
    create_import_report(kind: "classroom_links", checksum_sha256: nil, imported_by: @author, created_at: @launch,
                         details: { "selection" => { "school" => @school.public_id, "school_year" => school_year }, "expected_count" => 2 })
  end

  test "RM-17, RM-18: the active classrooms of the school get a new link; the old one dies, the students stay" do
    active = classroom(name: "6e 1")
    student = create_student(classroom: active)
    archived = classroom(name: "6e 2", status: "archived")
    elsewhere = classroom(school: create_school, name: "6e 1")
    tokens = [ active, archived, elsewhere ].map(&:link_token)
    report = launch

    Classroom::RegenerateClassroomLinksJob.perform_now(report.id)

    assert_equal [ "completed", 1, 1, 0, 0 ], report.reload.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_not_equal tokens.first, active.reload.link_token
    assert_match(/\A[0-9a-f]{12}\z/, active.link_token)
    assert_operator active.link_token_rotated_at, :>=, @launch
    assert_equal tokens.drop(1), [ archived.reload.link_token, elsewhere.reload.link_token ]
    preview = Queries::Classroom::JoinPreviewQuery.new
    assert_nil preview.link(token: tokens.first)
    assert_equal "6e 1", preview.link(token: active.link_token).classroom_name
    assert Orm::ClassroomStudent.exists?(classroom: active, student_id: student.id, left_at: nil)
  end

  test "RM-19: with every year, the active classroom of last year changes too" do
    current = classroom(name: "6e 1")
    old = classroom(name: "6e 1", school_year: current_school_year(on: 1.year.ago.to_date))
    old_token = old.link_token

    Classroom::RegenerateClassroomLinksJob.perform_now(launch(school_year: nil).id)

    assert_not_equal old_token, old.reload.link_token
    assert_operator current.reload.link_token_rotated_at, :>=, @launch
  end

  test "RM-21, RM-23: one school.changed per classroom with the report, no token anywhere; run again, nothing changes" do
    classrooms = Array.new(2) { classroom(name: "6e #{it}") }
    report = launch
    Classroom::RegenerateClassroomLinksJob.perform_now(report.id)
    tokens = classrooms.map { it.reload.link_token }

    events = Orm::AuditEvent.where(action: "school.changed")
    assert_equal [ @school.id ], events.distinct.pluck(:subject_id)
    assert_equal classrooms.map(&:public_id).sort, events.map { it.metadata["classroom_public_id"] }.sort
    assert(events.all? { it.metadata.values_at("change", "report_public_id") == [ "classroom_link_changed", report.public_id ] })
    stored = [ report.reload.attributes.to_json, Orm::AuditEvent.pluck(:metadata).to_json ].join
    assert(tokens.none? { stored.include?(it) })

    Classroom::RegenerateClassroomLinksJob.perform_now(report.id)

    assert_equal tokens, classrooms.map { it.reload.link_token }
    assert_equal 2, events.count
  end

  test "the right withdrawn before the run: the report fails with its reason, no link changes, no school.changed" do
    active = classroom(name: "6e 1")
    token = active.link_token
    report = launch
    @author.update!(team_role: "content")

    Classroom::RegenerateClassroomLinksJob.perform_now(report.id)

    assert_equal "failed", report.reload.status
    assert_equal [ "forbidden" ], report.import_errors.pluck("code")
    assert_equal token, active.reload.link_token
    assert_equal 0, Orm::AuditEvent.where(action: "school.changed").count
  end

  test "RM-21: a job that died is resumed: the link changed after the launch stays as it is, the other changes" do
    done = classroom(name: "6e 1")
    done.update_columns(link_token_rotated_at: @launch + 5.seconds)
    waiting = classroom(name: "6e 2")
    tokens = [ done.link_token, waiting.link_token ]
    report = launch
    report.update_columns(status: "importing", started_at: @launch + 1.second, processed_count: 1)

    Classroom::RegenerateClassroomLinksJob.perform_now(report.id)

    assert_equal [ "completed", 2, 1, 1, 0 ], report.reload.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal tokens.first, done.reload.link_token
    assert_not_equal tokens.last, waiting.reload.link_token
    assert_equal [ waiting.public_id ], Orm::AuditEvent.where(action: "school.changed").map { it.metadata["classroom_public_id"] }
  end

  test "an unexpected failure fails the report, then reaches the job" do
    classroom(name: "6e 1")
    report = launch

    stub_any_instance(Repositories::Classroom::ClassroomRepository, :link_regeneration_batch, ->(**) { raise "x" }) do
      assert_raises(RuntimeError) { Classroom::RegenerateClassroomLinksJob.perform_now(report.id) }
    end

    assert_equal "failed", report.reload.status
  end

  test "the lock of the job falls after the limit of a report without sign of life, so that a killed job blocks no one" do
    assert_equal UseCases::Catalog::StartImport::STALE_AFTER.seconds, Classroom::RegenerateClassroomLinksJob.concurrency_duration
    assert_equal 1, Classroom::RegenerateClassroomLinksJob.concurrency_limit
  end
end
