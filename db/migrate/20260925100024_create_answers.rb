# ADR-0054 : the propositions of a question (UDR-0007).
class CreateAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :answers do |t|
      t.references :question, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.integer :position, null: false
      t.string :content, limit: 500, null: false
      t.boolean :correct, null: false
      t.timestamps
      t.index [ :question_id, :position ], unique: true
    end
  end
end
