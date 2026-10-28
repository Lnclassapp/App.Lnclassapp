require "test_helper"
require Rails.root.join("db/migrate/20261028090200_add_unanswered_to_question_attempts").to_s

# ADR 0112 : `down` ne doit jamais effacer une copie d'élève.
class AddUnansweredToQuestionAttemptsMigrationTest < ActiveSupport::TestCase
  def migrate(direction) = ActiveRecord::Migration.suppress_messages { AddUnansweredToQuestionAttempts.new.migrate(direction) }

  test "down refuse s'il existe une question laissée vide, et ne supprime rien" do
    session = create_exercise_session
    question = session.exercise.questions.first
    Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: false, selected_answer_ids: [], unanswered: true,
                                 answered_at: Time.current)

    assert_raises(ActiveRecord::IrreversibleMigration) { migrate(:down) }
    assert_equal 1, Orm::QuestionAttempt.where(unanswered: true).count
  end
end
