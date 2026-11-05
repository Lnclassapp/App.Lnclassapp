require "test_helper"

# suivi-classe-lecon CA-8, CA-11: the same exercise (E3) is offered to the student in three places while their gap is
# pending (result page, notion of the lesson, « Fiches à revoir » of « Ma classe »), and nowhere once it is lifted.
class Assessment::RemediationProposalTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Géométrie")
    notion = revision_notion("Théorème de Thalès")
    sheet = notion.slice("remember", "method", "example", "pitfall")
    @thales = create_essential(course: @course, name: "Théorème de Thalès", sheet:)
    @e1 = create_exercise(essential: @thales, questions: 1, exercise_type: "evaluation")
    @e3 = create_exercise(essential: @thales, questions: 1, exercise_type: "fixation")
    @classroom = create_classroom(level: @course.level)
    @student = create_student(classroom: @classroom)
    @session = create_exercise_session(student: @student, exercise: @e1, status: "completed", score_percent: 20)
    @gap = create_gap(student: @student, essential: @thales, source_session: @session)
  end

  def href = course_sheet_path(@course.slug, "notion-#{@thales.slug}", anchor: "sheet-exercise-#{@e3.public_id}")

  test "CA-8: the result page, the lesson and « Ma classe » all offer E3" do
    sign_in_as @student

    get exercise_session_result_path(@session.public_id)
    assert_select "#session_gap_outcome a.ui-button-primary[href=?]", href, text: /Refais un exercice sur cette notion/

    get course_path(@course.slug)
    assert_select "section##{"notion-#{@thales.slug}"} p.sheet-todo a[href=?]", href, text: "fais cet exercice"

    get student_classroom_path
    assert_select "#student_classroom_gaps a[href=?][aria-label=?]", href, "Refaire un exercice sur Théorème de Thalès"
  end

  test "CA-11: once the gap is lifted, nothing is offered" do
    @gap.update!(status: "remediated", resolved_at: Time.current)
    sign_in_as @student

    get course_path(@course.slug)
    assert_select "p.sheet-todo", 0

    get student_classroom_path
    assert_select "#student_classroom_gaps", 0
  end

  test "a teacher reading the lesson sees no proposal" do
    teacher = create_teacher(school: @classroom.school, classrooms: [ @classroom ], material: @course.material)
    sign_in_as teacher

    get course_path(@course.slug)

    assert_select "p.sheet-todo", 0
  end
end
