require "application_system_test_case"

# Lot P2 de mvp-teacher-student — UDR enseignant §3.5 et §3.6, « Sur ordinateur (≥ lg) » (CA-I6). À 1280 px, la page de classe
# a deux colonnes égales (lien, exercices à gauche ; élèves à droite) et la fiche d'un élève a le résumé puis la gestion à
# gauche, les exercices puis « Fait seul » à droite, « Classes » actif dans la barre latérale.
class Classroom::ClassroomDesktopTest < ApplicationSystemTestCase
  DESKTOP = [ 1280, 900 ].freeze

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: create_level(name: "Tle"), series: create_series(name: "D"), name: "Tle D 1")
    @teacher = create_teacher(school:, classrooms: [ @classroom ])
    exercise = create_exercise(title: "Phases de la mitose", questions: 2)
    create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Konan")
    create_exercise_session(student: @student, exercise: create_exercise(title: "Seule"), status: "completed", score_percent: 70, completed_at: 1.day.ago)
    sign_in_as @teacher
  end

  test "à 1280 px, la page de classe a deux colonnes égales : lien et exercices à gauche, élèves à droite" do
    with_mobile_viewport(DESKTOP) do
      visit classroom_path(@classroom.public_id)

      assert_selector "#classroom_roster"
      assert_selector "nav [aria-current='page']", text: "Classes"
      link = rect("#classroom_link")
      exercises = rect("#assigned_exercises")
      roster = rect("#classroom_roster")
      assert_operator link[:top], :<, exercises[:top]
      assert_operator roster[:left], :>=, exercises[:right]
      assert_in_delta roster[:top], link[:top], 2
      assert_in_delta roster[:width], exercises[:width], 2
      assert_operator roster[:right] - link[:left], :<=, 912 + 1
    end
  end

  test "à 1280 px, la fiche d'un élève a le résumé puis la gestion à gauche, les exercices puis « Fait seul » à droite" do
    with_mobile_viewport(DESKTOP) do
      visit classroom_student_path(@classroom.public_id, @student.public_id)

      assert_selector "#student_file_summary"
      assert_selector "nav [aria-current='page']", text: "Classes"
      summary = rect("#student_file_summary")
      manage = rect("#student_file_manage")
      assignments = rect("#student_file_assignments")
      self_practice = rect("#student_file_self_practice")
      assert_operator summary[:top], :<, manage[:top]
      assert_operator assignments[:top], :<, self_practice[:top]
      assert_operator assignments[:left], :>=, summary[:right]
      assert_in_delta assignments[:left], self_practice[:left], 1
      assert_in_delta summary[:left], manage[:left], 1
      assert_in_delta assignments[:top], summary[:top], 2
      assert_in_delta assignments[:width], summary[:width], 2
      assert_operator manage[:top] - summary[:top], :<, 200, "la gestion ne suit pas le résumé"
    end
  end

  private

  def rect(selector)
    element = find(selector)
    page.evaluate_script(
      "(() => { const r = arguments[0].getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top, width: r.width } })()", element
    ).symbolize_keys
  end
end
