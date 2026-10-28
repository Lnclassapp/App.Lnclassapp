require "application_system_test_case"

# AS-07 à AS-11 (UDR-0022), UDR-0138 §3.2 : la copie. Le compteur « n/T répondues » suit les réponses, « Revoir le sujet » mène au
# sujet, « Rendre ma copie » est collé en bas à 390 px. Aucune proposition correcte n'est montrée ; les réponses survivent à un
# rechargement ; une copie rendue ne se rouvre plus.
class Assessment::ExerciseSessionTest < ApplicationSystemTestCase
  SCOPE = "assessment.exercise_sessions".freeze

  setup do
    exercise = create_exercise(title: "Méiose", questions: 2, statement: "Deux divisions successives.")
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours de l'exercice.
    @student = create_student_for(exercise.essential.course)
    @first, @second = exercise.questions.order(:position).to_a
    @session = create_exercise_session(student: @student, exercise:)
    sign_in_as @student
    assert_current_path student_home_path
  end

  test "le compteur suit les réponses, le brouillon survit au rechargement, la copie rendue mène au résultat" do
    visit exercise_session_path(@session.public_id)
    assert_selector "#copy-counter", text: "0/2"

    within("#question-1") { choose right_answer(@first).content }
    assert_selector "#copy-counter", text: "1/2"
    page.refresh
    assert_selector "#copy-counter", text: "1/2"
    within("#question-1") { assert_checked_field right_answer(@first).content }

    within("#question-2") { choose wrong_answer(@second).content }
    assert_selector "#copy-counter", text: "2/2"
    click_on I18n.t("#{SCOPE}.show.submit")

    assert_current_path exercise_session_result_path(@session.public_id)
    assert_equal [ "completed", 50 ], @session.reload.values_at(:status, :score_percent)
    visit exercise_session_path(@session.public_id)
    assert_current_path exercise_session_result_path(@session.public_id)
  end

  test "« Continuer ma copie » referme la confirmation et ne rend rien ; Échap fait de même" do
    visit exercise_session_path(@session.public_id)
    within("#question-1") { choose right_answer(@first).content }

    click_on I18n.t("#{SCOPE}.show.submit")
    within("dialog#copy-confirm[open]") do
      assert_text I18n.t("#{SCOPE}.show.missing", count: 1)
      click_on I18n.t("#{SCOPE}.show.keep_going")
    end
    assert_no_selector "dialog#copy-confirm[open]"
    assert_equal "started", @session.reload.status
    assert_current_path exercise_session_path(@session.public_id)
  end

  test "à 390 px : « Revoir le sujet » mène au sujet et « Rendre ma copie » colle au bas de l'écran" do
    with_mobile_viewport do
      visit exercise_session_path(@session.public_id)

      assert_selector "details#copy-statement[open]", text: "Deux divisions successives."
      assert_link I18n.t("#{SCOPE}.show.review_statement"), href: "#copy-statement"
      assert page.evaluate_script("Math.abs(document.querySelector('#copy-form button[type=submit]').getBoundingClientRect().bottom - window.innerHeight) < 40")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
    end
  end

  private

  def right_answer(question) = question.answers.find_by!(correct: true)
  def wrong_answer(question) = question.answers.where(correct: false).order(:id).first
end
