require "test_helper"

# CL-23, TR-04, AS-36, TR-02 (UDR-0010): the student home. The old feed raised NameError as soon as the student had a
# classroom, and a student without a classroom bounced between / and /students forever.
class Classroom::StudentHomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"))
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
    @course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"))
    @essential = create_essential(course: @course, name: "La méiose")
  end

  def tl(key, **) = I18n.t("classroom.student_homes.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/

  test "the student sees their classroom, its code in capitals, and no classmate by name" do
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yapo")
    sign_in_as @student

    get student_home_path

    assert_response :success
    assert_select "h1", text: including(tl("show.greeting", name: "Aya"))
    assert_select "#student_home_classroom", text: including("KFM37")
    assert_select "#student_home_classroom", text: including("Lycée Classique")
    assert_select "#student_home_classroom", text: including(tl("classroom_card.students", count: 2))
    assert_no_match "Yapo", response.body
    assert_no_match "Koffi", response.body
  end

  test "each assigned exercise with its subject, badge, best score, mastery and sessions, and the button to start" do
    started = create_exercise(essential: @essential, title: "Méiose, les étapes")
    fresh = create_exercise(essential: @essential, title: "Méiose, le bilan")
    create_assignment(classroom: @classroom, assignable: @essential)
    best = create_exercise_session(student: @student, exercise: started, status: "completed", score_percent: 80)
    create_badge(student: @student, exercise: started, level: "gold", session: best)
    session = create_exercise_session(student: @student, exercise: started)
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_exercises li", 2
    assert_select "#student_home_exercises li:first-child" do
      assert_select "*", text: "Méiose, les étapes"
      assert_select "*", text: "SVT"
      assert_select "*", text: tl("assigned_exercise.badge", level: "Or")
      assert_select "*", text: including(tl("assigned_exercise.best_score", score: 80))
      assert_select "*", text: I18n.t("assessment.badges.mastery.acquired")
      assert_select "*", text: tl("assigned_exercise.sessions", count: 1)
      assert_select "a[href='#{exercise_session_path(session.public_id)}']", text: including(tl("assigned_exercise.resume"))
    end
    assert_select "#student_home_exercises li:last-child" do
      assert_select "*", text: tl("assigned_exercise.sessions", count: 0)
      assert_select "form[action='#{exercise_sessions_path(fresh.public_id)}'][method=post] button",
                    text: including(tl("assigned_exercise.start"))
      assert_select "*", text: including(I18n.t("assessment.badges.mastery.acquired")), count: 0
    end
  end

  test "a failed exercise shows its mastery without any badge" do
    exercise = create_exercise(essential: @essential)
    create_assignment(classroom: @classroom, assignable: exercise)
    create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 40)
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_exercises li" do
      assert_select "*", text: I18n.t("assessment.badges.mastery.struggling")
      assert_select "*", text: including(tl("assigned_exercise.badge", level: "")), count: 0
    end
  end

  test "no exercise assigned, no sheet to review: the empty state, without the review section" do
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_exercises", text: including(tl("show.todo_empty"))
    assert_select "#student_home_gaps", 0
  end

  test "the sheets to review link to their sheet" do
    create_gap(student: @student, essential: @essential)
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_gaps", text: including(tl("pending_gaps.title"))
    assert_select "#student_home_gaps a[href='#{course_essential_path(@course.slug, @essential.slug)}']", text: "La méiose"
  end

  test "the recent activity is a lazy frame, then its frame alone with the last completed sessions" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 90)
    sign_in_as @student

    get student_home_path

    assert_select "turbo-frame#student_home_recent_activity[loading=lazy][src='#{student_home_path}']"
    assert_no_match "Méiose", response.body

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_response :success
    assert_select "turbo-frame#student_home_recent_activity[target=_top]" do
      assert_select "a[href='#{exercise_session_result_path(session.public_id)}']", text: including("Méiose")
      assert_select "*", text: including(I18n.t("assessment.badges.grade", grade: 18))
    end
    assert_no_match "KFM37", response.body
  end

  test "no completed session: the empty activity" do
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity", text: including(tl("recent_activity.empty"))
  end

  test "a student without an active classroom: one redirection, to a page that answers" do
    sign_in_as create_student

    get student_home_path

    assert_redirected_to pending_account_path
    follow_redirect!
    assert_response :success
  end

  test "a teacher and the team receive 403" do
    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user

      get student_home_path

      assert_response :forbidden
      sign_out
    end
  end
end
