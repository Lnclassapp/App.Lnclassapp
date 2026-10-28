require "test_helper"

# ADR-0113 §4.3: opening the lesson records the student's reading of its notions, and Turbo ignores a prefetched page's
# request when the click comes: a link to a lesson must never be prefetched, on any page of the student.
class Catalog::LessonLinksPrefetchTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Propriétés de Thalès")
    @notion = create_essential(course: @course, name: "Énoncé")
    @exercise = create_exercise(essential: @notion, questions: 1)
    @lesson_wide = create_lesson_wide_exercise(course: @course, questions: 1)
    @student = create_student_for(@course)
    sign_in_as @student
  end

  def assert_lesson_links_not_prefetched
    links = css_select("a[href^='/courses/']")
    assert_not_empty links, "the page has no link to a lesson to check"
    links.each do |link|
      owner = link.ancestors.find { it["data-turbo-prefetch"] } || link
      assert_equal "false", owner["data-turbo-prefetch"], "#{link['href']} can be prefetched"
    end
  end

  test "the catalog" do
    create_essential_read(student: @student, essential: @notion)

    get courses_path

    assert_response :success
    assert_lesson_links_not_prefetched
  end

  test "the student classroom: assigned courses and notions to review" do
    create_gap(student: @student, essential: @notion)
    create_assignment(classroom: Orm::ClassroomStudent.find_by!(student: @student).classroom, assignable: @exercise)

    get student_classroom_path

    assert_response :success
    assert_select "#course_#{@course.slug} a[href^='/courses/']"
    assert_lesson_links_not_prefetched
  end

  test "the exercise sheet" do
    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_lesson_links_not_prefetched
  end

  test "the result, with the outcome of a notion to review" do
    gap = create_gap(student: @student, essential: @notion)
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 40, gap:)

    get exercise_session_result_path(session.public_id)

    assert_response :success
    assert_select "a", text: I18n.t("assessment.session_results.gap_outcome.open_essential")
    assert_lesson_links_not_prefetched
  end

  test "the result of a lesson-wide exercise" do
    session = create_exercise_session(student: @student, exercise: @lesson_wide, status: "completed", score_percent: 100)

    get exercise_session_result_path(session.public_id)

    assert_response :success
    assert_lesson_links_not_prefetched
  end
end
