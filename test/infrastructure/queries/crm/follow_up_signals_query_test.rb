require "test_helper"

# CA-15 to CA-20 (ADR-XXXX contexte crm §4): the schools to follow up, with their reasons, in a constant number of queries.
class Queries::Crm::FollowUpSignalsQueryTest < ActiveSupport::TestCase
  setup do
    @me = create_team_member(team_role: "field")
    @other = create_team_member(team_role: "admin")
    @query = Queries::Crm::FollowUpSignalsQuery.new
  end

  def account(school, owner: @me, stage: "prospect", **attrs)
    Orm::CrmAccount.create!(school:, owner:, stage:, stage_changed_at: Time.current, **attrs)
  end

  def overdue(school, assignee: @me, due_on: Date.current - 1)
    Orm::CrmFollowUp.create!(school:, assignee:, due_on:, reason: "Rappeler", created_by: @me)
  end

  def mine(page: 1) = @query.mine(user_id: @me.id, page:)

  def reasons_of(page, school) = page.rows.find { it.school_id == school.id }&.reasons

  test "CA-15: an overdue open follow-up gives « overdue » to a school I own" do
    school = create_school
    account(school)
    overdue(school)

    assert_equal [ :overdue ], reasons_of(mine, school)
  end

  test "a follow-up due tomorrow, or already done, is no signal" do
    school = create_school
    account(school)
    overdue(school, due_on: Date.current + 1)
    Orm::CrmFollowUp.create!(school:, assignee: @me, due_on: Date.current - 3, reason: "x", status: "done", done_at: Time.current,
                             done_by: @me, created_by: @me)

    assert_empty mine.rows
  end

  test "CA-16: an activity 20 days ago and nothing since gives « usage_lost »" do
    school = create_school
    account(school)
    teacher = create_teacher(school:)
    classroom = create_classroom(school:)
    student = create_student(classroom:)
    create_exercise_session(student:, started_at: 20.days.ago)

    assert_equal [ :usage_lost ], reasons_of(mine, school)
    assert teacher
  end

  test "CA-17: a « demo_done » school with no interaction for 8 days gives « demo_stalled »" do
    school = create_school
    account(school, stage: "demo_done")
    Orm::CrmInteraction.create!(school:, author: @me, kind: "call", occurred_at: 8.days.ago, outcome: "neutral")

    assert_equal [ :demo_stalled ], reasons_of(mine, school)
  end

  test "a recent interaction clears « demo_stalled »" do
    school = create_school
    account(school, stage: "demo_done")
    Orm::CrmInteraction.create!(school:, author: @me, kind: "call", occurred_at: 8.days.ago, outcome: "neutral")
    Orm::CrmInteraction.create!(school:, author: @me, kind: "call", occurred_at: 1.day.ago, outcome: "neutral")

    assert_empty mine.rows
  end

  test "CA-18: the first teacher attached 15 days ago and no activity gives « registered_idle »" do
    school = create_school
    account(school)
    create_teacher(school:)
    Orm::TeacherSchool.where(school:).update_all(created_at: 15.days.ago)

    assert_equal [ :registered_idle ], reasons_of(mine, school)
  end

  test "CA-19: a deactivated school, or one shown as « lost », is never listed" do
    off = create_school(status: "inactive")
    account(off)
    overdue(off)
    lost = create_school
    account(lost, stage: "lost", lost_reason: "price")
    overdue(lost)

    assert_empty mine.rows
  end

  test "only the schools I own are listed, plus the ones where an overdue follow-up is mine" do
    owned = create_school
    account(owned)
    overdue(owned)
    elsewhere = create_school
    account(elsewhere, owner: @other)
    overdue(elsewhere, assignee: @other)
    given = create_school
    account(given, owner: @other)
    overdue(given)

    assert_equal [ owned.id, given.id ].sort, mine.rows.map(&:school_id).sort
    assert_equal 2, mine.total_count
  end

  test "the whole team view lists every school with a signal, with its owner" do
    elsewhere = create_school
    account(elsewhere, owner: @other)
    overdue(elsewhere, assignee: @other)
    orphan = create_school
    overdue(orphan)

    page = @query.all(page: 1)

    assert_equal [ elsewhere.id, orphan.id ].sort, page.rows.map(&:school_id).sort
    assert_equal @other.first_name, page.rows.find { it.school_id == elsewhere.id }.owner_name.split.first
  end

  test "rows come with their school, DRENA and signals, the most signals first, 25 per page" do
    drena = create_drena(name: "Abidjan 1")
    one = create_school(name: "A école", drena:)
    two = create_school(name: "B école", drena:)
    [ one, two ].each { account(it) }
    overdue(one)
    overdue(two)
    create_teacher(school: two)
    Orm::TeacherSchool.where(school: two).update_all(created_at: 30.days.ago)

    rows = mine.rows

    assert_equal [ two.id, one.id ], rows.map(&:school_id)
    assert_equal [ %i[overdue registered_idle], "Abidjan 1", two.public_id ], [ rows.first.reasons, rows.first.drena_name, rows.first.school_public_id ]
    assert_equal [ 1, 1 ], [ mine.page, mine.pages ]
  end

  test "the number of queries does not grow with the number of schools" do
    seed = -> { create_school.tap { |school| account(school); overdue(school); create_teacher(school:) } }
    2.times { seed.call }
    few = count_queries { mine }

    4.times { seed.call }
    many = count_queries { mine }

    assert_equal few, many
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
