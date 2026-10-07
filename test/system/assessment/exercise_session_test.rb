require "application_system_test_case"

# AS-07 à AS-11 (UDR-0022) : dans sa session, l'élève valide sans rien cocher (erreur dans la carte), puis répond aux deux
# questions ; le verdict et la progression arrivent après chaque réponse, et la dernière propose « Voir mon résultat » —
# tout sans rechargement de page, sur un bureau comme à 390 px. Aucune proposition correcte n'est montrée. UDR-0076 §3.3 :
# la question suivante arrive avec le verdict, « Question suivante » l'affiche sans requête.
class Assessment::ExerciseSessionTest < ApplicationSystemTestCase
  # La page de résultat (Lot C3), que Turbo précharge au survol de « Voir mon résultat », n'est pas encore fusionnée :
  # une doublure répond sur sa route, comme dans test/system/classroom/join_test.rb. Un contrôleur fusionné est
  # chargeable : la doublure s'efface d'elle-même.
  unless Object.const_defined?("Assessment::SessionResultsController")
    Assessment.const_set(:SessionResultsController, Class.new(AuthenticatedController) { def show = render(html: "résultat", layout: true) })
  end

  SCOPE = "assessment.exercise_sessions".freeze

  setup do
    exercise = create_exercise(title: "Méiose", questions: 2)
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours de l'exercice.
    @student = create_student_for(exercise.essential.course)
    @first, @second = exercise.questions.order(:position).to_a
    @first.update!(content: "Combien de cellules donne la méiose ?", explanation: "Quatre cellules filles.")
    @second.update!(content: "La méiose réduit-elle le nombre de chromosomes ?")
    @session = create_exercise_session(student: @student, exercise:)
    sign_in_as @student
    assert_current_path student_home_path
  end

  test "réponse vide, puis deux réponses corrigées une à une, jusqu'au lien du résultat, sans rechargement" do
    play_the_session
  end

  test "le même parcours sur un écran de 390 px" do
    with_mobile_viewport { play_the_session }
  end

  # UDR-0022, amendement du 2026-10-02 (UDR-0057) : à 390 × 844, une seule action principale et au plus 5 blocs avant
  # le pli, sur la question comme sur son verdict ; la consigne n'est donnée que pour plusieurs réponses (R4, R6).
  test "à 390 px, la session suit la règle de sobriété ; « Coche N propositions. » seulement pour plusieurs réponses" do
    @second.update!(question_type: "multiple_correct_2")

    with_mobile_viewport do
      visit exercise_session_path(@session.public_id)

      within("#question-card") { assert_no_selector "fieldset > p" }
      assert_single_primary_action
      assert_blocks_above_fold "#main .max-w-2xl > *"

      choose wrong_answer(@first).content
      click_on I18n.t("#{SCOPE}.question_card.submit")
      within("#feedback-card") { assert_text I18n.t("#{SCOPE}.feedback_card.encouragement.error") }
      assert_single_primary_action
      assert_blocks_above_fold "#main .max-w-2xl > *"

      click_on I18n.t("#{SCOPE}.feedback_card.next")
      within("#question-card") do
        assert_selector "fieldset > p", exact_text: I18n.t("#{SCOPE}.question_card.hint", count: 2)
        assert_no_text "Plusieurs propositions correctes"
      end
      assert_single_primary_action
    end
  end

  private

  def play_the_session
    visit exercise_session_path(@session.public_id)
    assert_selector "h1", text: "Méiose"

    assert_no_page_reload do
      within("#question-card") { click_on I18n.t("#{SCOPE}.question_card.submit") }
      assert_selector "#attempt-errors", text: I18n.t("activemodel.errors.models.dtos/assessment/attempt_input.attributes.answer_ids.blank")

      choose wrong_answer(@first).content
      click_on I18n.t("#{SCOPE}.question_card.submit")
      within("#feedback-card") do
        assert_text I18n.t("#{SCOPE}.feedback_card.verdict.error")
        assert_text "Quatre cellules filles."
        assert_no_text(/correcte/i)
      end
      assert_selector "#progress_bar progress[value='50']"

      # UDR-0076 §3.3, ADR-0076 : la question suivante est arrivée avec le verdict ; l'afficher ne coûte aucune requête.
      requests = server_requests
      click_on I18n.t("#{SCOPE}.feedback_card.next")
      assert_selector "#question-card", text: "La méiose réduit-elle le nombre de chromosomes ?"
      assert_equal requests, server_requests, "« Question suivante » ne doit rien demander au serveur"
      assert_equal "La méiose réduit-elle le nombre de chromosomes ?", page.evaluate_script("document.activeElement.textContent").strip
      choose right_answer(@second).content
      click_on I18n.t("#{SCOPE}.question_card.submit")
      assert_selector "#feedback-card", text: I18n.t("#{SCOPE}.feedback_card.verdict.success")
      assert_selector "#progress_bar progress[value='100']"
      assert_link I18n.t("#{SCOPE}.feedback_card.result"), href: exercise_session_result_path(@session.public_id)
    end
    assert_equal [ "completed", 50 ], @session.reload.values_at(:status, :score_percent)
  end

  # Les requêtes du document (fetch de Turbo, formulaires, frames), lues dans le Resource Timing du navigateur.
  def server_requests = page.evaluate_script(<<~JS)
    performance.getEntriesByType("resource").filter((entry) => ["fetch", "xmlhttprequest"].includes(entry.initiatorType)).length
  JS

  def right_answer(question) = question.answers.find_by!(correct: true)
  def wrong_answer(question) = question.answers.where(correct: false).order(:id).first
end
