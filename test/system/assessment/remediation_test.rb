require "application_system_test_case"

# Chantier remediation-ciblee (PRD §3 et §4, Lot D), dans un navigateur réel. Un seul parcours, des sessions de 2 questions
# (ADR-0069 §9). La porte V5 de la feuille de route : le parcours réel de l'élève ouvre la lacune, lance la remédiation et
# la lève. L'élève rate « Thalès 1 » (« Cette fiche de révision passe à revoir »), retrouve la notion sur son accueil, l'ouvre dans la leçon, démarre
# « Thalès 3 » (fixation, ADR-0101 §4.2) depuis la leçon, réussit (« Notion levée ! ») ; la notion quitte son
# accueil. Les autres cas sont prouvés au niveau du contrôleur et de la query.
class Assessment::RemediationTest < ApplicationSystemTestCase
  RESULTS = "assessment.session_results".freeze
  QUESTIONS = 2

  test "l'élève rate, refait l'exercice proposé et lève la notion" do
    maths = create_material(name: "Mathématiques")
    course = create_course(material: maths, name: "Géométrie")
    classroom = create_classroom(level: course.level, series: course.series)
    student = create_student(classroom:, first_name: "Awa", last_name: "Bamba")
    thales = create_essential(course:, name: "Théorème de Thalès")
    failed = create_exercise(essential: thales, title: "Thalès 1", exercise_type: "evaluation", questions: QUESTIONS, position: 1)
    create_exercise(essential: thales, title: "Thalès 2", exercise_type: "evaluation", questions: QUESTIONS, position: 2)
    offered = create_exercise(essential: thales, title: "Thalès 3", exercise_type: "fixation", questions: QUESTIONS, position: 3)
    sign_in_as student

    visit exercise_path(failed.public_id)
    click_on I18n.t("assessment.exercises.show.start")
    play(correct: 0)
    assert_selector "#session_gap_outcome", text: "Cette notion passe à revoir."

    visit student_home_path
    within("#student_next_step[data-state=review]") do
      assert_selector "#student_next_step_title", text: "Théorème de Thalès"
      click_on I18n.t("classroom.student_homes.next_step.review.open")
    end
    # CA-25 : « Revoir la notion » mène à la leçon, sur la notion, où l'exercice est proposé (la notion n'a plus de page).
    assert_current_path course_path(course.slug)
    # La feuille de la notion porte l'exercice proposé (« Exercice 3 ») ; la copie de remédiation se joue sur sa page.
    assert_selector ".ps-sheet#notion-#{thales.slug} turbo-frame#sheet-exercise-#{offered.public_id}"
    visit exercise_path(offered.public_id)
    click_on I18n.t("assessment.exercises.show.start")
    remediation = play(correct: QUESTIONS)
    assert_equal "remediation", Orm::ExerciseSession.find_by!(public_id: remediation).kind
    assert_selector "#session_gap_outcome", text: "Notion levée !"

    visit student_home_path
    assert_no_selector "#student_next_step[data-state=review]"
  end

  private

  # Remplit et rend la copie de la session ouverte : les `correct` premières questions justes (la proposition 1 est la
  # bonne, fabrique create_exercise), les autres fausses. → public_id de la session.
  def play(correct:) = hand_in_copy(rights: correct, questions: QUESTIONS)
end
