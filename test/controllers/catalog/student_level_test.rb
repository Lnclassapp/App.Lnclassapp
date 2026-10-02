require "test_helper"

# UDR-0013 et ADR-0035, amendements du 2026-10-01 : un élève de Tle D ne voit, n'ouvre et ne commence que les cours de
# Tle D et ceux de Tle sans série ; un autre niveau répond 404 sans rien confirmer. Les autres rôles lisent tout.
class Catalog::StudentLevelTest < ActionDispatch::IntegrationTest
  setup do
    tle = create_level(name: "Tle")
    @own = create_course(name: "Génétique", level: tle, series: create_series(name: "D"))
    @common = create_course(name: "La conscience", level: tle)
    @other = create_course(name: "La cellule", level: create_level(name: "2nde"))
    @other_essential = create_essential(course: @other)
    @other_exercise = create_exercise(essential: @other_essential)
    @student = create_student_for(@own)
  end

  def tl(key, **) = I18n.t("catalog.courses.index.#{key}", **)

  test "the catalogue of a Tle D student lists Tle D and common Tle courses only, without the level filter" do
    sign_in_as @student

    get courses_path

    assert_response :success
    assert_select "#courses_list > li", 2
    assert_select "#course_#{@own.slug}"
    assert_select "#course_#{@common.slug}"
    assert_select "#course_#{@other.slug}", 0
    assert_select "select[name=level]", 0
    assert_select "select[name=material]"
    assert_match tl("student_subtitle"), response.body
  end

  test "a course, a sheet and an exercise of another level answer 404 to the student, and no session starts" do
    sign_in_as @student

    get course_path(@other.slug)
    assert_response :not_found
    get course_essential_path(@other.slug, @other_essential.slug)
    assert_response :not_found
    get exercise_path(@other_exercise.public_id)
    assert_response :not_found
    post exercise_sessions_path(@other_exercise.public_id)
    assert_response :not_found
    assert_not Orm::ExerciseSession.exists?

    get course_path(@own.slug)
    assert_response :success
    get course_path(@common.slug)
    assert_response :success
  end

  test "a student without a class of the year is told to join one; a teacher still reads every level" do
    sign_in_as create_student

    get courses_path
    assert_select "#courses_list", 0
    assert_select "#courses_empty", text: /#{Regexp.escape(tl("no_class_title"))}/
    sign_out

    sign_in_as create_teacher
    get course_path(@other.slug)
    assert_response :success
    get courses_path
    assert_select "#course_#{@other.slug}"
  end

  # Revue de sécurité de la mise en production du 2026-10-01 : une session ouverte avant la règle, sur un exercice d'un
  # autre niveau, ne se joue plus, ne reçoit plus de réponse et ne montre plus son résultat à son élève.
  test "a session of another level, opened before the rule, can neither be played, answered nor read back by its student" do
    started = create_exercise_session(student: @student, exercise: @other_exercise)
    completed = create_exercise_session(student: @student, exercise: @other_exercise, status: "completed", score_percent: 50)
    question = @other_exercise.questions.first
    sign_in_as @student

    get exercise_session_path(started.public_id)
    assert_response :not_found
    post exercise_session_attempts_path(started.public_id),
         params: { attempt: { question_id: question.id, answer_ids: [ question.answers.first.id ] } },
         as: :turbo_stream
    assert_response :not_found
    assert_not Orm::QuestionAttempt.exists?
    get exercise_session_result_path(completed.public_id)
    assert_response :not_found
  end
end
