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

      assert_selector "#session_grade", text: "20/20"
    end
  end
end
