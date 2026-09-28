require "test_helper"

# Every lot builds its data with these factories (plan boucle-pedagogique §0a.5): each one
# must write a row the database accepts, with the defaults alone.
class FactoriesTest < ActiveSupport::TestCase
  test "every factory creates a valid row with its defaults" do
    %i[create_user create_student create_teacher create_team_member create_school_admin create_invitation create_pin_recovery_code
       create_backup_code create_login_session create_login_attempt create_audit_event create_drena create_school
       create_classroom create_assignment create_level create_series link_level_series create_material create_course
       create_essential create_import_report create_exercise create_exercise_session create_attempt create_badge create_gap].each do |factory|
      record = factory == :create_user ? create_user(role: "student") : public_send(factory)

      assert record.persisted?, factory
    end
  end

  test "a student may join a classroom, a teacher gets a profile, a school and classrooms" do
    classroom = create_classroom
    student = create_student(classroom:)
    teacher = create_teacher(school: classroom.school, classrooms: [ classroom ], onboarded: false)

    assert_equal [ student ], classroom.classroom_students.map(&:student)
    assert_nil teacher.teacher_profile.onboarding_completed_at
    assert_equal [ teacher ], classroom.teacher_classrooms.map(&:teacher)
    assert_equal [ teacher ], classroom.school.teacher_schools.map(&:teacher)
  end

  test "a team member holds an encrypted TOTP secret, returned in clear to the test" do
    member = create_team_member(second_factor: true)
    stored = Orm::TotpCredential.connection.select_value("SELECT secret FROM totp_credentials WHERE user_id = #{member.id}")

    assert_equal member.totp_secret, member.totp_credential.secret
    assert_not_includes stored, member.totp_secret
    assert_nil create_team_member(second_factor: false).totp_credential
  end

  test "a student has a MENA number of their own; a member of the direction has a position, a school and a second factor" do
    students = [ create_student, create_student ]
    school = create_school
    censor = create_school_admin(school:, position: "censor")

    assert(students.all? { Entities::Identity::StudentNumber.valid?(it.student_number) })
    assert_equal 2, students.map(&:student_number).uniq.size
    assert_nil create_student(student_number: nil).student_number
    assert_equal [ school.id, "censor", nil ], censor.school_staffs.sole.then { [ it.school_id, it.position, it.left_at ] }
    assert_equal censor.totp_secret, censor.totp_credential.secret
    assert create_school_admin.school_staffs.sole.position == "principal"
  end

  test "create_user gives a school_admin a confirmed second factor by default, and nobody else" do
    admin = create_user(role: "school_admin")

    assert_not_nil admin.totp_credential.confirmed_at
    assert_nil create_user(role: "school_admin", second_factor: false).totp_credential
    %w[student teacher team].each { assert_nil create_user(role: it).totp_credential, it }
  end

  test "secrets are stored as HMAC digests and PINs by bcrypt" do
    invitation = create_invitation(kind: "school_staff")
    code = create_pin_recovery_code(code: "87654321")

    assert_equal secret_digest(invitation.token), invitation.token_digest
    assert_equal secret_digest("87654321"), code.code_digest
    assert create_user(role: "teacher").authenticate_pin("2468")
    assert_equal [ "principal", nil ], [ invitation.position, invitation.team_role ]
  end

  test "archived rows carry their archive date" do
    assert create_classroom(status: "archived", join_code: nil).archived_at
    assert create_assignment(status: "archived").archived_by
    assert create_course(status: "archived").archived_at
    assert_nil create_essential(status: "draft").published_at
  end

  test "an exercise has single choice questions, a completed session its score" do
    exercise = create_exercise(questions: 3)
    session = create_exercise_session(exercise:, status: "completed", score_percent: 67)
    wrong = create_attempt(session:, correct: false)

    assert_equal [ 3, [ 1 ] * 3 ], [ exercise.questions.count, exercise.questions.map { |question| question.answers.count(&:correct) } ]
    assert_equal [ 2, 100 ], [ session.correct_count, session.progress_percent ]
    assert_not Orm::Answer.find(wrong.selected_answer_ids.first).correct
  end

  test "a gap opens on a failed session and makes remediation sessions" do
    gap = create_gap
    remediation = create_exercise_session(student: gap.student, exercise: gap.source_session.exercise, gap:)

    assert_equal [ 40, "remediation" ], [ gap.source_session.score_percent, remediation.kind ]
    assert create_gap(status: "remediated").resolved_at
  end

  test "the seed referential gives 7 levels, 5 series, 10 pairs and 7 materials" do
    referential = seed_referential

    assert_equal %w[6eme 5eme 4eme 3eme 2nde 1ere tle], referential[:levels].keys
    assert_equal %w[a c a1 a2 d], referential[:series].keys
    assert_equal [ 7, 5, 10, 7 ], [ Orm::Level.count, Orm::Series.count, Orm::LevelSeries.count, Orm::Material.count ]
    assert_equal %w[a c], referential[:levels]["2nde"].series.map(&:slug).sort
    assert_equal 28, Orm::ClassroomPlanEntry.count
  end

  test "the school year follows the Ivorian calendar" do
    assert_equal "2026-2027", current_school_year(on: Date.new(2026, 9, 1))
    assert_equal "2025-2026", current_school_year(on: Date.new(2026, 8, 31))
  end
end
