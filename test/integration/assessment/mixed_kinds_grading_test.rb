require "test_helper"

# CA-12, ADR-0091 §4.3 : tout juste ou faux par question, la note ne change pas. Cinq questions de types mélangés, dont
# quatre justes, donnent 80 % et 16/20, comme avec le calcul d'avant.
class Assessment::MixedKindsGradingTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  test "cinq questions de types mélangés, quatre justes : 80 % et 16/20" do
    exercise = create_exercise(title: "Mélange", questions: 1)
    choice = exercise.questions.sole
    blank = create_kind_question(exercise:, question_type: "fill_blank", answers: %w[Abidjan], content: "Capitale : ___ .")
    number = create_kind_question(exercise:, question_type: "numeric", answers: [ "-2" ])
    steps = create_kind_question(exercise:, question_type: "ordering", answers: %w[A B C])
    pairs = create_kind_question(exercise:, question_type: "matching", answers: [ %w[a 1], %w[b 2], %w[c 3] ])
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    answer = ->(question, attempt) do
      post exercise_session_attempts_path(session.public_id), headers: TURBO, params: { attempt: { question_id: question.id, **attempt } }
      assert_response :success
    end
    indices = lambda do |question, wanted|
      ids = question.answers.order(:position).map(&:id)
      shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids:, avoid: ids)
      wanted.map { shuffled.index(ids[it]) }
    end

    answer.(choice, answer_ids: [ choice.answers.find_by!(correct: true).id ])
    answer.(blank, response_text: "abidjan")
    answer.(number, response_text: "−2")
    answer.(steps, display_order: indices.(steps, [ 0, 1, 2 ]))
    answer.(pairs, display_order: indices.(pairs, [ 1, 0, 2 ]))

    assert_equal [ true, true, true, true, false ], Orm::QuestionAttempt.order(:id).pluck(:correct)
    assert_equal [ "completed", 80, 4 ], session.reload.values_at(:status, :score_percent, :correct_count)
    get exercise_session_result_path(session.public_id)
    assert_select "#session_grade", text: "16/20"
  end
end
