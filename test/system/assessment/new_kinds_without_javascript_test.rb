require "application_system_test_case"

# correction-comme-en-classe, Lot C (UDR-0140 §3, PRD « Sans JavaScript ») : le devoir se fait sans JavaScript. La liste
# déroulante, la zone de texte et l'envoi marchent ; après vérification, la grille se coche avec des cases simples.
# Chrome tourne avec les scripts coupés.
class Assessment::NewKindsWithoutJavascriptTest < ApplicationSystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ], options: { name: :chrome_without_javascript } do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    %w[--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage --blink-settings=scriptEnabled=false].each do
      options.add_argument(it)
    end
  end

  setup do
    @exercise = create_exercise(title: "Devoir Thalès", questions: 0, exercise_type: "evaluation")
    @list = @exercise.questions.create!(position: 1, content: "Les points A, M et B doivent être ___.", question_type: "select", points: 2)
    [ "parallèles", "alignés", "proportionnelles" ].each_with_index { |text, rank| @list.answers.create!(position: rank + 1, content: text, correct: rank == 1) }
    @written = @exercise.questions.create!(position: 2, content: "Le point est-il sur la droite ?", question_type: "written", points: 2,
                                           starter: "Non, car…", explanation: "Corrigé : oui, car les rapports sont égaux.",
                                           criteria: [ "Je cite le théorème", "Je conclus" ])
    @notebook = @exercise.questions.create!(position: 3, content: "Sur ton cahier, trace la construction.", question_type: "notebook", points: 2,
                                            explanation: "Corrigé du cahier.")
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  test "la liste, la zone de texte et l'envoi marchent sans JavaScript ; la grille se coche, rien n'est enregistré" do
    visit exercise_session_path(@session.public_id)

    assert_selector "textarea[placeholder='Non, car…']"
    assert_selector "legend", text: "(2 points)", count: 3
    assert_text I18n.t("assessment.exercise_sessions.kinds.notebook.to_do")
    select "alignés", from: "q1-display_order"
    fill_in "q2-response_text", with: "Oui, car <b>AM/AB</b> = AN/AC."
    click_on I18n.t("assessment.exercise_sessions.show.submit")

    assert_selector "#question_review_#{@written.id} [data-written-answer]", text: "Oui, car <b>AM/AB</b> = AN/AC."
    assert_text "Corrigé : oui, car les rapports sont égaux."
    assert_text "Corrigé du cahier."
    assert_selector "#question_review_#{@list.id}", text: I18n.t("assessment.session_results.show.correct")
    within("#question_review_#{@written.id}") do
      boxes = all("fieldset input[type=checkbox]", visible: :all)
      assert_equal 2, boxes.size
      boxes.each { assert_not it.checked? }
      check "Je cite le théorème"
      assert_checked_field "Je cite le théorème"
    end
    attempt = Orm::QuestionAttempt.find_by!(question: @written)
    assert_equal [ "Oui, car <b>AM/AB</b> = AN/AC.", false ], [ attempt.response_text, attempt.correct ]
    assert_equal 100, @session.reload.score_percent
  end
end
