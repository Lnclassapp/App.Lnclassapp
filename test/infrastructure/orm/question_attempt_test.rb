require "test_helper"

# ADR-0115 §6 : la réponse rédigée tient en 2 000 caractères (menace.md, W2, W8).
class Orm::QuestionAttemptTest < ActiveSupport::TestCase
  setup do
    @session = create_exercise_session(exercise: create_exercise(questions: 1))
    @question = @session.exercise.questions.first
  end

  def attempt(text) = Orm::QuestionAttempt.create!(exercise_session: @session, question: @question, correct: false, selected_answer_ids: [],
                                                   response_text: text, answered_at: Time.current)

  test "2 000 caractères sont gardés, 2 001 sont refusés par la base" do
    assert_equal 2_000, attempt("é" * 2_000).reload.response_text.length
    Orm::QuestionAttempt.delete_all
    assert_raises(ActiveRecord::ValueTooLong) { attempt("é" * 2_001) }
  end

  # W8 : la grille cochée à l'écran n'est jamais enregistrée ; une tentative ne garde que ses réponses.
  test "une tentative n'a pas de colonne pour une grille de vérification" do
    assert_equal %w[answered_at correct exercise_session_id id question_id response_text selected_answer_ids unanswered],
                 Orm::QuestionAttempt.column_names.sort
  end
end
