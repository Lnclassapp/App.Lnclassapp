require "application_system_test_case"

# CA-7, UDR-0087 §3.4 et §3.10 : l'élève range les étapes avec « Monter » et « Descendre » (désactivés aux extrémités, le
# focus suit l'étape, une annonce dit sa place), sans glisser-déposer, puis valide : le bon ordre est juste.
class Assessment::QuestionOrderingTest < ApplicationSystemTestCase
  SCOPE = "assessment.exercise_sessions".freeze
  STEPS = %w[Prophase Métaphase Anaphase].freeze

  test "ranger trois étapes avec les flèches, puis valider : « Bonne réponse »" do
    exercise = create_exercise(title: "Mitose", questions: 0)
    create_kind_question(exercise:, question_type: "ordering", answers: STEPS, content: "Range les étapes.")
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    with_mobile_viewport do
      visit exercise_session_path(session.public_id)
      assert_no_selector "select[name='attempt[display_order][]']"
      assert_selector "[data-assessment--ordering-target=item]:first-child button[data-direction=up][disabled]"

      STEPS.each_with_index do |step, rank|
        while (current = shown.index(step)) > rank
          find("[data-assessment--ordering-target=item]", text: step).find("button[data-direction=up]").click
          assert_equal current - 1, shown.index(step)
        end
      end
      # ADR-0091 §4.4 : le mélange ne donne jamais le bon ordre ; au moins un déplacement, donc une annonce.
      assert_selector "[role=status]", text: /position/, visible: :all
      click_on I18n.t("#{SCOPE}.question_card.submit")

      assert_selector "#feedback-card", text: I18n.t("#{SCOPE}.feedback_card.verdict.success")
    end
  end

  private

  def shown = all("[data-assessment--ordering-target=item] span.flex-1").map(&:text)
end
