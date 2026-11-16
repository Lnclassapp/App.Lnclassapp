require "test_helper"
require "rake"

# Chantier entonnoir-aarrr, lot 1 : `bin/rails entonnoir:brut`, l'entonnoir brut des élèves par semaine, en lecture seule,
# sans aucune donnée personnelle (PRD §5).
class EntonnoirTaskTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 11, 16, 12)
  MONDAY = Time.zone.local(2026, 11, 2, 9)

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("entonnoir:brut")
    travel_to NOW
  end

  def brut
    task = Rake::Task["entonnoir:brut"]
    task.reenable
    capture_io { task.invoke }.first
  end

  def table_counts = %w[users classroom_students exercise_sessions essential_reads].map { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{it}") }

  test "prints the funnel per week and per channel, counts only" do
    classroom = create_classroom
    alone = create_student(classroom:, joined_via: "standard", created_at: MONDAY, first_name: "Aïcha", last_name: "Traoré")
    create_essential_read(student: alone)
    2.times { create_exercise_session(student: alone, status: "completed", score_percent: 80) }
    linked = create_student(classroom:, joined_via: "link", created_at: MONDAY + 1.day)
    create_exercise_session(student: linked)
    create_student(classroom:, joined_via: "code", created_at: MONDAY + 7.days)

    out = brut

    assert_includes out, "lecture seule"
    assert_match(/^2026-11-02 +total +2 +1 +2 +1 +1 +0$/, out)
    assert_match(/^ +standard +1 +1 +1 +1 +1 +0$/, out)
    assert_match(/^ +link +1 +0 +1 +0 +0 +0$/, out)
    assert_match(/^2026-11-09 +total +1 +0 +0 +0 +0 +0$/, out)
    assert_match(/^ +code +1 +0 +0 +0 +0 +0$/, out)
    assert_match(/^TOTAL +total +3 +1 +2 +1 +1 +0$/, out)
    assert_match(/^ +sans classe +0 +0 +0 +0 +0 +0$/, out)
    [ "Aïcha", "Traoré", alone.contact, alone.public_id ].each { assert_not_includes out, it }
  end

  test "runs in a read-only transaction: a write inside it is refused, nothing changes" do
    create_student(created_at: MONDAY)
    before = table_counts
    writer = ->(**) { Orm::User.update_all(first_name: "Écrit") }

    error = stub_any_instance(Queries::Identity::StudentFunnelQuery, :weekly, writer) { assert_raises(ActiveRecord::StatementInvalid) { brut } }

    assert_match(/read-only transaction/, error.message)
    assert_equal before, table_counts
  end

  test "an empty base: one line, no table" do
    assert_includes brut, "Aucun élève inscrit."
  end
end
