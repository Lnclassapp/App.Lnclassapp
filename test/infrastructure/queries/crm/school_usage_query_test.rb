require "test_helper"

# ADR-XXXX (contexte crm) §4: the usage of a batch of schools, same definitions as Queries::School::TeamDashboardQuery,
# read in a constant number of queries.
class Queries::Crm::SchoolUsageQueryTest < ActiveSupport::TestCase
  TODAY = Date.current

  setup do
    @school = create_school
    @classroom = create_classroom(school: @school)
  end

  def usage_of(*schools) = Queries::Crm::SchoolUsageQuery.new.call(school_ids: schools.map(&:id), today: TODAY)

  def session_for(student, days_ago:)
    create_exercise_session(student:, started_at: days_ago.days.ago)
  end

  test "a school nobody joined has zeros and no date" do
    usage = usage_of(@school).fetch(@school.id)

    assert_equal Entities::Crm::SchoolUsage.new(school_id: @school.id, accounts_count: 0, active_students_count: 0,
                                                last_activity_on: nil, first_attached_on: nil), usage
  end

  test "every requested school is answered, even without any row" do
    other = create_school

    assert_equal [ @school.id, other.id ].sort, usage_of(@school, other).keys.sort
  end

  test "accounts are teachers, direction and placed students, never an anonymized one" do
    create_teacher(school: @school)
    create_teacher(school: @school, anonymized_at: Time.current)
    create_school_admin(school: @school)
    create_student(classroom: @classroom)
    create_student(classroom: @classroom, anonymized_at: Time.current)
    create_student
    create_teacher

    assert_equal 3, usage_of(@school).fetch(@school.id).accounts_count
  end

  test "a student who left the classroom is not an account of the school" do
    student = create_student(classroom: @classroom)
    Orm::ClassroomStudent.find_by!(student:).update!(left_at: Time.current)

    assert_equal 0, usage_of(@school).fetch(@school.id).accounts_count
  end

  test "an archived direction account is not counted" do
    create_school_admin(school: @school, archived_at: 1.day.ago)

    assert_equal 0, usage_of(@school).fetch(@school.id).accounts_count
  end

  test "active students are the placed ones who started an exercise in the last 14 days, counted once" do
    recent = create_student(classroom: @classroom)
    old = create_student(classroom: @classroom)
    outsider = create_student
    2.times { session_for(recent, days_ago: 2) }
    session_for(old, days_ago: 20)
    session_for(outsider, days_ago: 1)

    assert_equal 1, usage_of(@school).fetch(@school.id).active_students_count
  end

  test "the last activity is the latest of an exercise session and a classroom assignment" do
    student = create_student(classroom: @classroom)
    session_for(student, days_ago: 10)
    assert_equal TODAY - 10, usage_of(@school).fetch(@school.id).last_activity_on

    create_assignment(classroom: @classroom, assigned_at: 4.days.ago)
    assert_equal TODAY - 4, usage_of(@school).fetch(@school.id).last_activity_on
  end

  test "the first attachment is the earliest of the teacher, direction and student rows" do
    create_teacher(school: @school).then { Orm::TeacherSchool.find_by!(teacher: it).update!(created_at: 30.days.ago) }
    create_school_admin(school: @school, joined_at: 50.days.ago)
    create_student(classroom: @classroom, joined_at: 10.days.ago)

    assert_equal TODAY - 50, usage_of(@school).fetch(@school.id).first_attached_on
  end

  test "usage stays separate between schools of the same batch" do
    other = create_school
    create_teacher(school: other)
    create_teacher(school: other)
    create_teacher(school: @school)

    usage = usage_of(@school, other)

    assert_equal [ 1, 2 ], [ usage.fetch(@school.id).accounts_count, usage.fetch(other.id).accounts_count ]
  end

  test "the number of queries does not grow with the number of schools" do
    schools = Array.new(2) { create_school }
    schools.each { create_teacher(school: it) }
    few = count_queries { usage_of(*schools) }

    more = Array.new(4) { create_school.tap { |school| create_teacher(school:) } }
    many = count_queries { usage_of(*schools, *more) }

    assert_equal few, many
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
