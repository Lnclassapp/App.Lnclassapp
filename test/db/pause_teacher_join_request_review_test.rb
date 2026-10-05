require "test_helper"
require Rails.root.join("db/migrate/20261003120000_pause_teacher_join_request_review").to_s

# ADR-0073: validation is paused. The migration approves the requests still pending, through "auto" and by no one, and
# attaches their teachers to their school; refused requests and teachers who already have a primary school stay as they
# are, and so do requests no sign-up could make today (anonymized account, school not active, open withdrawal). Each test runs in the rolled back transaction of the test: PostgreSQL rolls the constraint changes back with it.
class PauseTeacherJoinRequestReviewTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  def migrate(direction) = ActiveRecord::Migration.suppress_messages { PauseTeacherJoinRequestReview.new.migrate(direction) }

  def via_constraint
    connection.check_constraints("school_join_requests").find { it.name == "school_join_requests_decided_via_values" }.expression
  end

  setup do
    @school = create_school
    migrate(:down) # the former ways: team and sponsor
  end

  test "up approves the pending requests through auto, attaches their teachers, and leaves refused requests alone" do
    awa = create_teacher(school: nil)
    pending = create_join_request(school: @school, teacher: awa)
    refused = create_join_request(school: @school, status: "rejected")
    attached = create_teacher(school: create_school)
    already = create_join_request(school: @school, teacher: attached)

    migrate(:up)

    assert_equal [ "approved", "auto", nil ], [ pending.reload.status, pending.decided_via, pending.decided_by_id ]
    assert pending.decided_at
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: awa).pluck(:school_id, :primary)
    assert_equal [ "rejected", "team" ], [ refused.reload.status, refused.decided_via ]
    assert_equal 0, Orm::TeacherSchool.where(teacher: refused.teacher_id).count
    assert_equal "approved", already.reload.status
    assert_equal 1, Orm::TeacherSchool.where(teacher: attached).count, "son école principale reste la seule"
    assert_match(/'auto'/, via_constraint)
  end

  test "an anonymized account, a school not active, an open withdrawal: the request stays pending, no one is attached" do
    anonymized = create_join_request(school: @school, teacher: create_teacher(school: nil, anonymized_at: Time.current))
    closed = create_join_request(school: create_school(status: "inactive"))
    withdrawn = create_join_request(school: @school)
    create_teacher_departure(teacher: Orm::User.find(withdrawn.teacher_id), school: @school, detached_by: create_team_member)

    migrate(:up)

    [ anonymized, closed, withdrawn ].each do |request|
      assert_equal "pending", request.reload.status
      assert_equal 0, Orm::TeacherSchool.where(teacher_id: request.teacher_id).count
    end
  end

  test "a teacher already linked to the school without being attached makes up fail, and nothing is approved" do
    awa = create_teacher(school: nil)
    request = create_join_request(school: @school, teacher: awa)
    Orm::TeacherSchool.create!(teacher: awa, school: @school, primary: false)

    assert_raises(ActiveRecord::RecordNotUnique) { connection.transaction(requires_new: true) { migrate(:up) } }

    assert_equal "pending", request.reload.status
  end

  test "down brings the former ways back" do
    migrate(:up)
    migrate(:down)

    assert_no_match(/'auto'/, via_constraint)
    assert_match(/'sponsor'/, via_constraint)
  end
end
