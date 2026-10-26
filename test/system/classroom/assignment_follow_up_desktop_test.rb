require "application_system_test_case"

# Lot P3 de mvp-teacher-student — UDR enseignant §3.8, « Sur ordinateur (≥ lg) ». À 1280 px, « Voir l'exercice » est à droite
# du titre ; deux colonnes égales : à gauche progression, cases par badge, prochain geste et questions, à droite les élèves.
class Classroom::AssignmentFollowUpDesktopTest < ApplicationSystemTestCase
  DESKTOP = [ 1280, 900 ].freeze

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: create_level(name: "Tle"), series: create_series(name: "D"), name: "Tle D 1")
    @teacher = create_teacher(school:, classrooms: [ @classroom ])
    exercise = create_exercise(title: "Phases de la mitose", questions: 2)
    @assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Konan")
    session = create_exercise_session(student:, exercise:, status: "completed", score_percent: 60,
                                      classroom_assignment: @assignment, completed_at: 1.day.ago)
    exercise.questions.order(:position).each { |question| create_attempt(session:, question:, correct: true) }
  end

  test "à 1280 px, le bouton est à droite du titre, la progression à gauche et les élèves à droite en colonnes égales" do
    sign_in_as @teacher
    with_mobile_viewport(DESKTOP) do
      visit classroom_assignment_path(@classroom.public_id, @assignment.public_id)

      assert_selector "#comprehension_questions"
      title = rect("h1")
      button = rect("a", text: "Voir l'exercice")
      assert_operator button[:left], :>, title[:right]
      assert_in_delta title[:top], button[:top], 60

      progress = rect("#follow_up_progress")
      next_step = rect("#comprehension_next_step")
      questions = rect("#comprehension_questions")
      students = rect("#comprehension_panel")
      assert_operator progress[:top], :<, next_step[:top]
      assert_operator next_step[:top], :<, questions[:top]
      assert_operator students[:left], :>=, questions[:right]
      assert_in_delta students[:top], progress[:top], 2
      assert_in_delta students[:width], questions[:width], 2
      assert_no_selector "#comprehension_panel a", text: "Voir l'exercice"
    end
  end

  private

  def rect(selector, **filters)
    element = find(selector, **filters)
    page.evaluate_script(
      "(() => { const r = arguments[0].getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top, width: r.width } })()", element
    ).symbolize_keys
  end
end
