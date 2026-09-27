# ADR-0054 : one immutable attempt per question and session, hence no timestamps.
class CreateQuestionAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :question_attempts do |t|
      t.references :exercise_session, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.references :question, null: false, foreign_key: { on_delete: :restrict }
      t.bigint :selected_answer_ids, array: true, null: false
      t.boolean :correct, null: false
      t.datetime :answered_at, null: false
      t.index [ :exercise_session_id, :question_id ], unique: true
    end

    add_check_constraint :question_attempts, "cardinality(selected_answer_ids) > 0",
                         name: "question_attempts_selected_answer_ids_present"
  end
end
