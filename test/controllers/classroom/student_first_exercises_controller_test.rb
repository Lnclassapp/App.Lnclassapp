require "test_helper"

# Chantier entree-et-accueil-eleve-allegees, Lot D, PRD CA-12 à CA-15 (UDR accueil-eleve-qr-fenetre-inviter §3.2) :
# la fenêtre « Ton premier exercice », cadre différé du shell.
class Classroom::StudentFirstExercisesControllerTest < ActionDispatch::IntegrationTest
  FRAME = "student_first_exercise_prompt".freeze
  HEADERS = { "Turbo-Frame" => FRAME }.freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"), level: create_level(name: "Tle"))
    @student = create_student(classroom: @classroom)
    course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"), level: @classroom.level)
    @essential = create_essential(course:, name: "La méiose")
  end

  def tc(key, **) = I18n.t("catalog.courses.next_exercise.#{key}", **)

  test "CA-12: the home carries the deferred frame, not the card" do
    create_exercise(essential: @essential, title: "Les étapes de la méiose")
    sign_in_as @student

    get student_home_path

    assert_select "turbo-frame##{FRAME}[src=?][loading=eager]", student_first_exercise_path
    assert_select "#student_first_exercise", 0
  end

  test "CA-13: any other screen of the student carries the frame too; a teacher does not" do
    create_exercise(essential: @essential)
    sign_in_as @student

    get courses_path
    assert_select "turbo-frame##{FRAME}[src=?]", student_first_exercise_path

    sign_in_as create_teacher(classrooms: [ @classroom ])
    get teacher_home_path
    assert_select "turbo-frame##{FRAME}", 0
  end

  test "CA-13: the exercise page itself does not carry the frame" do
    exercise = create_exercise(essential: @essential, title: "Les étapes de la méiose")
    sign_in_as @student

    get exercise_path(exercise.public_id)

    assert_response :success
    assert_select "turbo-frame##{FRAME}", 0
  end

  test "CA-13: the frame holds an open window with the first exercise, one tap to start (out of the frame), a way to close" do
    exercise = create_exercise(essential: @essential, title: "Les étapes de la méiose")
    sign_in_as @student

    get student_first_exercise_path, headers: HEADERS

    assert_response :success
    assert_select "turbo-frame##{FRAME} dialog#student_first_exercise_modal[open]" do
      assert_select "h2", text: tc("first")
      assert_select "h3", text: "Les étapes de la méiose"
      assert_select "p", text: "SVT · Génétique"
      assert_select "form[action=?][data-turbo-frame=_top] button#student_first_exercise_start[aria-label=?]",
                    exercise_sessions_path(exercise.public_id), tc("start_aria", title: "Les étapes de la méiose"), text: /#{tc('start')}/
      assert_select "#student_first_exercise_later[data-action='modal#close']"
    end
  end

  test "CA-13: a copy in progress is resumed from the window, at the next question" do
    exercise = create_exercise(essential: @essential, title: "Les étapes de la méiose", questions: 3)
    copy = create_exercise_session(student: @student, exercise:, answered_count: 1)
    sign_in_as @student

    get student_first_exercise_path, headers: HEADERS

    assert_select "a#student_first_exercise_start[href=?][data-turbo-frame=_top]", exercise_session_path(copy.public_id), text: /#{tc('resume', number: 2)}/
  end

  test "the assignment brought by the class is the first exercise, « given by your class »" do
    brought = create_student(classroom: @classroom, joined_via: "code")
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential, title: "Méiose, les étapes"), assigned_at: 1.day.ago)
    sign_in_as brought

    get student_first_exercise_path, headers: HEADERS

    assert_select "h3", text: "Méiose, les étapes"
    assert_select "p", text: "SVT · #{tc('assigned')}"
  end

  test "nothing to propose: an empty frame, and no flag (an exercise may come)" do
    sign_in_as @student

    get student_first_exercise_path, headers: HEADERS

    assert_response :success
    assert_select "turbo-frame##{FRAME}"
    assert_select "dialog", 0
    get student_home_path
    assert_select "turbo-frame##{FRAME}[src]"
  end

  test "CA-14: a copy handed in, whatever the mark: an empty frame, the flag is set, the next screens carry no frame" do
    create_exercise_session(student: @student, exercise: create_exercise(essential: @essential), status: "completed", score_percent: 10)
    create_exercise(essential: @essential, title: "Mitose")
    sign_in_as @student

    get student_first_exercise_path, headers: HEADERS

    assert_response :success
    assert_select "dialog", 0
    get student_home_path
    assert_select "turbo-frame##{FRAME}", 0
    get courses_path
    assert_select "turbo-frame##{FRAME}", 0
  end

  test "an abandoned copy is not a copy handed in" do
    create_exercise_session(student: @student, exercise: create_exercise(essential: @essential), status: "abandoned")
    sign_in_as @student

    get student_first_exercise_path, headers: HEADERS
    get student_home_path

    assert_select "turbo-frame##{FRAME}[src]"
  end

  test "CA-15: a teacher and a school director are refused, a visitor is sent to the sign-in page" do
    sign_in_as create_teacher(classrooms: [ @classroom ])
    get student_first_exercise_path, headers: HEADERS
    assert_response :forbidden

    reset!
    sign_in_as create_school_admin(school: @classroom.school)
    get student_first_exercise_path, headers: HEADERS
    assert_response :forbidden

    reset!
    get student_first_exercise_path, headers: HEADERS
    assert_redirected_to new_session_path
  end

  test "CA-13: the focused exercise screen carries no window" do
    copy = create_exercise_session(student: @student, exercise: create_exercise(essential: @essential, questions: 3), answered_count: 1)
    sign_in_as @student

    get exercise_session_path(copy.public_id)

    assert_response :success
    assert_select "turbo-frame##{FRAME}", 0
  end

  test "the install invitation waits while the window can open, and comes back once a copy is handed in" do
    sign_in_as @student
    get student_home_path
    assert_select "#install_banner", 0

    create_exercise_session(student: @student, exercise: create_exercise(essential: @essential), status: "completed", score_percent: 80)
    get student_first_exercise_path, headers: HEADERS
    get student_home_path
    assert_select "#install_banner", 1
  end
end
