require "application_system_test_case"

# CA-8, UDR-0087 §3.4, UDR-0138 §3.2 : l'élève touche un élément à gauche puis un à droite ; un même numéro relie les deux, toucher une paire
# la défait. la question n'est comptée qu'une fois tous les éléments de gauche reliés ; trois paires justes : juste.
class Assessment::QuestionMatchingTest < ApplicationSystemTestCase
  SCOPE = "assessment.exercise_sessions".freeze
  PAIRS = [ %w[3(x+1) 3x+3], %w[2(x-4) 2x-8], %w[5(2+x) 10+5x] ].freeze

  test "relier trois paires au doigt, en défaire une, puis rendre la copie : 20/20" do
    exercise = create_exercise(title: "Développer", questions: 0)
    create_kind_question(exercise:, question_type: "matching", answers: PAIRS, content: "Relie chaque expression.")
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    with_mobile_viewport do
      visit exercise_session_path(session.public_id)

      link "3(x+1)", "2x-8"
      assert_selector "[data-assessment--matching-target=right][aria-pressed=true]", text: "2x-8"
      right("2x-8").click
      assert_no_selector "[aria-pressed=true]"

      PAIRS.first(2).each { |left, right| link left, right }
      assert_selector "#copy-counter", text: "0/1"
      link(*PAIRS.last)
      assert_selector "[data-assessment--matching-target=left] [data-pair]", text: "3"
      assert_selector "#copy-counter", text: "1/1"
      click_on I18n.t("#{SCOPE}.show.submit")

      assert_selector "#session_grade", text: "20/20"
    end
  end

  private

  def left(text) = find("[data-assessment--matching-target=left]", text:)
  def right(text) = find("[data-assessment--matching-target=right]", text:)

  def link(left_text, right_text)
    left(left_text).click
    right(right_text).click
  end
end
