require "application_system_test_case"

# CA-6, UDR-0087 §3.4 : l'élève tape 2 puis touche « ± » : le champ montre « -2 » et la réponse est juste. Une saisie illisible
# garde « Valider » désactivé.
class Assessment::QuestionNumericTest < ApplicationSystemTestCase
  SCOPE = "assessment.exercise_sessions".freeze

  test "taper 2, toucher « ± », valider : « -2 » est juste ; illisible, « Valider » reste désactivé" do
    exercise = create_exercise(title: "Calcul", questions: 0)
    create_kind_question(exercise:, question_type: "numeric", answers: [ "-2" ], content: "Calcule 3 - 5.")
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    with_mobile_viewport do
      visit exercise_session_path(session.public_id)
      field = find_field("attempt[response_text]")
      field.send_keys("2,,")
      assert_button I18n.t("#{SCOPE}.question_card.submit"), disabled: true
      field.send_keys(:backspace, :backspace)
      find("button[aria-label='#{I18n.t("#{SCOPE}.kinds.numeric.sign")}']").click
      assert_field "attempt[response_text]", with: "-2"
      click_on I18n.t("#{SCOPE}.question_card.submit")

      within("#feedback-card") do
        assert_text I18n.t("#{SCOPE}.feedback_card.verdict.success")
        assert_selector "p[aria-labelledby=feedback-selected]", text: "-2"
      end
    end
  end
end
