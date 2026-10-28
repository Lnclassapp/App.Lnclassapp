require "application_system_test_case"

# Chantier remediation-ciblee (PRD §3 et §4, Lot D), dans un navigateur réel. Un seul parcours, des sessions de 2 questions
# (ADR-0069 §9). La porte V5 de la feuille de route : le parcours réel de l'élève ouvre la lacune, lance la remédiation et
# la lève. L'élève rate « Thalès 1 » (« Cette fiche de révision passe à revoir »), retrouve la fiche sur son accueil, lit « À revoir depuis le… » sur la fiche, démarre
# « Thalès 3 » (fixation, ADR-0101 §4.2) depuis la liste des exercices, réussit (« Fiche de révision levée ! ») ; la fiche quitte son
# accueil. Puis l'enseignant de la classe lit l'élève dans « Fiche de révision levée ». Les autres cas sont prouvés au niveau du
# contrôleur et de la query.
class Assessment::RemediationTest < ApplicationSystemTestCase
  RESULTS = "assessment.session_results".freeze
  SESSIONS = "assessment.exercise_sessions".freeze
  QUESTIONS = 2
  # Le POST de la fiche, puis la page de la session, sous une suite chargée (session_result_test.rb).
  START_WAIT = 10

  test "l'élève rate, refait l'exercice proposé et lève la fiche ; l'enseignant le lit dans « Fiche de révision levée »" do
    maths = create_material(name: "Mathématiques")
    course = create_course(material: maths, name: "Géométrie")
    classroom = create_classroom(level: course.level, series: course.series)
    teacher = create_teacher(material: maths, classrooms: [ classroom ])
    student = create_student(classroom:, first_name: "Awa", last_name: "Bamba")
    thales = create_essential(course:, name: "Théorème de Thalès")
    failed = create_exercise(essential: thales, title: "Thalès 1", exercise_type: "evaluation", questions: QUESTIONS, position: 1)
    create_exercise(essential: thales, title: "Thalès 2", exercise_type: "evaluation", questions: QUESTIONS, position: 2)
    offered = create_exercise(essential: thales, title: "Thalès 3", exercise_type: "fixation", questions: QUESTIONS, position: 3)
    sign_in_as student

    visit exercise_path(failed.public_id)
    click_on I18n.t("assessment.exercises.student_progress.start")
    play(correct: 0)
    assert_selector "#session_gap_outcome", text: "Cette notion passe à revoir."

    visit student_home_path
    within("#student_next_step[data-state=review]") do
      assert_selector "#student_next_step_title", text: "Théorème de Thalès"
      click_on I18n.t("classroom.student_homes.next_step.review.open")
    end
    assert_selector "#essential_gap_since", text: "À revoir depuis le"
    within("#essential_exercise_#{offered.public_id}") { click_on I18n.t("catalog.essentials.exercise_progress.start") }
    remediation = play(correct: QUESTIONS)
    assert_equal "remediation", Orm::ExerciseSession.find_by!(public_id: remediation).kind
    assert_selector "#session_gap_outcome", text: "Notion levée !"

    visit student_home_path
    assert_no_selector "#student_next_step[data-state=review]"

    sign_out
    sign_in_as teacher
    visit classroom_essential_path(classroom.public_id, course.slug, thales.slug)
    assert_selector "#classroom_essential_gaps_lifted", text: "Fiche de révision levée"
    assert_selector "#classroom_essential_gaps_lifted li", text: "Awa Bamba"
    assert_no_selector "#classroom_essential_gaps_pending"
  end

  private

  # Répond aux questions de la session ouverte : les `correct` premières justes (la proposition 1 est la bonne, fabrique
  # create_exercise), les autres fausses ; puis « Voir mon résultat ». → public_id de la session.
  def play(correct:)
    assert_current_path %r{\A/sessions/[^/]+\z}, wait: START_WAIT
    public_id = current_path.split("/").last
    QUESTIONS.times do |index|
      within("#question-card", text: "Question #{index + 1}") { choose(index < correct ? "Proposition 1" : "Proposition 2") }
      click_on I18n.t("#{SESSIONS}.question_card.submit")
      assert_selector "#feedback-card"
      click_on I18n.t("#{SESSIONS}.feedback_card.#{index == QUESTIONS - 1 ? 'result' : 'next'}")
    end
    assert_current_path exercise_session_result_path(public_id)
    public_id
  end
end
