require "application_system_test_case"

# AS-07 à AS-11 (UDR-0022), UDR-0087 §3.2–3.3 (CA-1 à CA-3) : la séance en mode concentré, sans en-tête ni menus ; la croix,
# la barre et « n/T » en haut ; « Valider » collé en bas et désactivé tant que rien n'est choisi. Le verdict et la question
# suivante arrivent sans rechargement (UDR-0076 §3.3). La croix demande confirmation : « Continuer l'exercice » referme la
# feuille, « Quitter » ramène à la page de l'exercice, la session restant ouverte. Aucune proposition correcte n'est montrée.
class Assessment::ExerciseSessionTest < ApplicationSystemTestCase
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

  test "mode concentré : ni en-tête ni menus, « Valider » désactivé puis deux réponses corrigées sans rechargement" do
    play_the_session
  end

  test "à 390 px : la croix ouvre la feuille ; « Continuer » la referme, « Quitter » mène à la page, la session reste ouverte" do
    with_mobile_viewport do
      visit exercise_session_path(@session.public_id)
      choose wrong_answer(@first).content
      click_on I18n.t("#{SCOPE}.question_card.submit")
      assert_selector "#feedback-card"

      quit_cross.click
      within("dialog#quit-dialog[open]") do
        assert_text I18n.t("#{SCOPE}.quit_dialog.title")
        assert_text I18n.t("#{SCOPE}.quit_dialog.resume", number: 2)
        click_on I18n.t("#{SCOPE}.quit_dialog.continue")
      end
      assert_no_selector "dialog#quit-dialog[open]"
      assert_selector "#feedback-card"
      # CA-1 : l'action colle au bas de l'écran.
      assert page.evaluate_script("Math.abs(document.querySelector('#feedback-actions').getBoundingClientRect().bottom - window.innerHeight) < 2")

      quit_cross.click
      within("dialog#quit-dialog[open]") { click_on I18n.t("#{SCOPE}.quit_dialog.quit") }
      assert_current_path exercise_path(@session.exercise.public_id)
    end
    assert_equal [ "started", 1 ], @session.reload.values_at(:status, :answered_count)
  end

  private

  def play_the_session
    visit exercise_session_path(@session.public_id)
    assert_no_selector "header.sticky.z-40"
    assert_no_selector "aside"
    assert_equal I18n.t("#{SCOPE}.quit_dialog.trigger"), page.evaluate_script(<<~JS)
      (document.querySelector("a[href], button:not([disabled]), input, select, textarea") || {}).getAttribute("aria-label")
    JS
    assert_selector "#progress_counter", text: "1/2"
    assert_button I18n.t("#{SCOPE}.question_card.submit"), disabled: true

    assert_no_page_reload do
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
      assert_selector "#progress_counter", text: "2/2"
      assert_equal "La méiose réduit-elle le nombre de chromosomes ?", page.evaluate_script("document.activeElement.textContent").strip
      choose right_answer(@second).content
      click_on I18n.t("#{SCOPE}.question_card.submit")
      assert_selector "#feedback-card", text: I18n.t("#{SCOPE}.feedback_card.verdict.success")
      assert_selector "#progress_bar progress[value='100']"
      assert_link I18n.t("#{SCOPE}.feedback_card.result"), href: exercise_session_result_path(@session.public_id)
    end
    assert_equal [ "completed", 50 ], @session.reload.values_at(:status, :score_percent)
  end

  def quit_cross = find("a[aria-label='#{I18n.t("#{SCOPE}.quit_dialog.trigger")}']")

  # Les requêtes du document (fetch de Turbo, formulaires, frames), lues dans le Resource Timing du navigateur.
  def server_requests = page.evaluate_script(<<~JS)
    performance.getEntriesByType("resource").filter((entry) => ["fetch", "xmlhttprequest"].includes(entry.initiatorType)).length
  JS

  def right_answer(question) = question.answers.find_by!(correct: true)
  def wrong_answer(question) = question.answers.where(correct: false).order(:id).first
end
