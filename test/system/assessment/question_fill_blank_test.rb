require "application_system_test_case"

# CA-4, UDR-0087 §3.4 : au doigt et au clavier, l'élève écrit dans le blanc ; « Valider » s'active quand il a écrit, et la
# réponse en majuscules avec des espaces en trop est juste. Le texte saisi revient dans « Ton choix ».
class Assessment::QuestionFillBlankTest < ApplicationSystemTestCase
  SCOPE = "assessment.exercise_sessions".freeze

  test "écrire dans le blanc, valider, lire « Bonne réponse » et son texte" do
    exercise = create_exercise(title: "Géographie", questions: 0)
    create_kind_question(exercise:, question_type: "fill_blank", answers: %w[Abidjan],
                         content: "La capitale économique de la Côte d'Ivoire est ___ .")
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    with_mobile_viewport do
      visit exercise_session_path(session.public_id)
      assert_button I18n.t("#{SCOPE}.question_card.submit"), disabled: true
      find_field("attempt[response_text]").send_keys("ABIDJAN  ")
      click_on I18n.t("#{SCOPE}.question_card.submit")

      within("#feedback-card") do
        assert_text I18n.t("#{SCOPE}.feedback_card.verdict.success")
        assert_selector "p[aria-labelledby=feedback-selected]", text: "ABIDJAN"
      end
    end
  end
end
