# ADR-0054 : questions of an exercise, closed list of types.
class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.references :exercise, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.integer :position, null: false
      t.text :content, null: false
      t.text :explanation
      t.string :question_type, null: false
      t.timestamps
      t.index [ :exercise_id, :position ], unique: true
    end

    add_check_constraint :questions,
                         "question_type IN ('true_false','single_choice','multiple_correct_2','multiple_correct_3')",
                         name: "questions_question_type_values"
  end
end
