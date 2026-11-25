require "application_system_test_case"

# CA-6, UDR-0087 §3.4, UDR-0138 §3.2 : l'élève tape 2 puis touche « ± » : le champ montre « -2 » et la réponse est juste. Une saisie
# illisible ne compte pas comme répondue.
class Assessment::QuestionNumericTest < ApplicationSystemTestCase
  SCOPE = "assessment.exercise_sessions".freeze

  test "taper 2, toucher « ± », rendre la copie : « -2 » est juste ; illisible, la question n'est pas comptée" do
    exercise = create_exercise(title: "Calcul", questions: 0)
    create_kind_question(exercise:, question_type: "numeric", answers: [ "-2" ], content: "Calcule 3 - 5.")
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    with_mobile_viewport do
      visit exercise_session_path(session.public_id)
      field = find_field("q1-response_text")
      field.send_keys("2,,")
      assert_selector "#copy-counter", text: "0/1"
      field.send_keys(:backspace, :backspace)
      find("button[aria-label='#{I18n.t("#{SCOPE}.kinds.numeric.sign")}']").click
      assert_field "q1-response_text", with: "-2"
      assert_selector "#copy-counter", text: "1/1"
      click_on I18n.t("#{SCOPE}.show.submit")

      assert_selector "#session_badge[aria-label='Médaille Diamant']"
      assert_no_text "20/20"
    end
  end

  # Chantier premier-exercice-ux : « x = 8 » dans une réponse en nombre. Le message s'écrit sous le champ ; « Vérifier ma copie »
  # ne parle pas de question sans réponse et ne montre pas la bulle du navigateur : il ramène l'élève au champ.
  test "une saisie illisible se dit sous le champ, et l'envoi ramène au champ au lieu de « sans réponse »" do
    exercise = create_exercise(title: "Équation", questions: 0)
    create_kind_question(exercise:, question_type: "numeric", answers: [ "8" ], content: "Résous 2x = 16.")
    create_kind_question(exercise:, question_type: "numeric", answers: [ "3" ], content: "Résous x + 1 = 4.")
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student
    invalid = I18n.t("#{SCOPE}.kinds.numeric.invalid")

    with_mobile_viewport do
      visit exercise_session_path(session.public_id)
      find_field("q2-response_text").fill_in(with: "3")
      field = find_field("q1-response_text")
      field.fill_in(with: "x = 8")
      assert_no_selector "#q1-numeric-error", visible: true
      find_field("q2-response_text").click
      assert_selector "#q1-numeric-error", text: invalid
      assert_selector "#q1-response_text[aria-invalid='true']"

      click_on I18n.t("#{SCOPE}.show.submit")
      assert_no_selector "dialog#copy-confirm[open]"
      assert_selector "#q1-response_text:focus"
      assert_selector "#q1-numeric-error", text: invalid
      assert_current_path exercise_session_path(session.public_id)

      field.fill_in(with: "8")
      assert_no_selector "#q1-numeric-error", visible: true
      assert_selector "#copy-counter", text: "2/2"
      click_on I18n.t("#{SCOPE}.show.submit")
      assert_selector "#session_badge[aria-label='Médaille Diamant']"
    end
  end
end
