require "application_system_test_case"

# UDR-0138 : à 390 px, l'élève ouvre la feuille, « Faire l'exercice », répond à 4 questions sur 5, recharge et retrouve ses
# réponses, « Vérifier ma copie », confirme les questions vides, puis lit sa note sur 20 avec la question vide « Sans réponse ».
class Assessment::ExerciseCopyTest < ApplicationSystemTestCase
  SCOPE = "assessment.exercise_sessions".freeze

  setup do
    @exercise = create_exercise(title: "Méiose", questions: 5, statement: "Étudie la méiose.")
    @questions = @exercise.questions.order(:position).to_a
    @student = create_student_for(@exercise.essential.course)
    sign_in_as @student
  end

  test "feuille, copie, brouillon retrouvé au rechargement, confirmation des questions vides, résultat" do
    with_mobile_viewport do
      visit exercise_path(@exercise.public_id)
      assert_selector "#exercise-sheet", text: "Étudie la méiose."
      assert_no_selector "#exercise_questions input"
      click_on I18n.t("assessment.exercises.show.start")

      assert_selector "form#copy-form"
      assert_selector "#copy-counter", text: "0"
      @questions.first(4).each_with_index { |question, index| answer(question, index.even?) }
      assert_selector "#copy-counter", text: "4"

      page.refresh
      assert_selector "#copy-counter", text: "4"
      within("#question-1") { assert_checked_field right(@questions.first).content }
      draft_key = "lnclass:copy:#{Orm::ExerciseSession.find_by!(student: @student).public_id}"
      assert_not_nil page.evaluate_script("localStorage.getItem(#{draft_key.to_json})")

      click_on I18n.t("#{SCOPE}.show.submit")
      within("dialog#copy-confirm[open]") do
        assert_text I18n.t("#{SCOPE}.show.missing", count: 1)
        click_on I18n.t("#{SCOPE}.show.confirm")
      end

      assert_selector "#session_grade"
      # CA-20 : le brouillon est effacé une fois la copie rendue.
      assert_nil page.evaluate_script("localStorage.getItem(#{draft_key.to_json})")
      click_on I18n.t("components.reveal.more")
      assert_selector "#question_review_#{@questions.last.id}", text: I18n.t("assessment.session_results.show.unanswered")
    end
    session = Orm::ExerciseSession.find_by!(student: @student)
    assert_equal [ "completed", 2 ], [ session.status, session.correct_count ]
  end

  test "« Continuer ma copie » referme la confirmation et ne rend rien ; Échap fait de même" do
    session = create_exercise_session(student: @student, exercise: @exercise)
    visit exercise_session_path(session.public_id)
    answer(@questions.first, true)

    click_on I18n.t("#{SCOPE}.show.submit")
    within("dialog#copy-confirm[open]") do
      assert_text I18n.t("#{SCOPE}.show.missing", count: 4)
      click_on I18n.t("#{SCOPE}.show.keep_going")
    end
    assert_no_selector "dialog#copy-confirm[open]"

    click_on I18n.t("#{SCOPE}.show.submit")
    assert_selector "dialog#copy-confirm[open]"
    page.driver.browser.action.send_keys(:escape).perform
    assert_no_selector "dialog#copy-confirm[open]"

    assert_equal "started", session.reload.status
    assert_current_path exercise_session_path(session.public_id)
  end

  test "à 390 px : « Revoir le sujet » mène au sujet, « Vérifier ma copie » colle au bas de l'écran, la page ne déborde pas" do
    session = create_exercise_session(student: @student, exercise: @exercise)
    with_mobile_viewport do
      visit exercise_session_path(session.public_id)

      assert_selector "details#copy-statement[open]", text: "Étudie la méiose."
      assert_link I18n.t("#{SCOPE}.show.review_statement"), href: "#copy-statement"
      assert page.evaluate_script("Math.abs(document.querySelector('#copy-form button[type=submit]').getBoundingClientRect().bottom - window.innerHeight) < 40")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
    end
  end

  private

  def right(question) = question.answers.find_by!(correct: true)
  def wrong(question) = question.answers.where(correct: false).order(:id).first

  def answer(question, correct)
    number = @questions.index(question) + 1
    within("#question-#{number}") { choose (correct ? right(question) : wrong(question)).content }
  end
end
