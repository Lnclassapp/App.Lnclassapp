# ADR-0043 : knowledge gaps, one pending gap per student and essential sheet.
class CreateKnowledgeGaps < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_gaps do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :essential, null: false, foreign_key: { on_delete: :restrict }
      t.references :source_session, null: false, foreign_key: { to_table: :exercise_sessions, on_delete: :restrict }
      t.string :status, null: false, default: "pending"
      t.integer :failed_sessions_count, null: false, default: 1
      t.datetime :resolved_at
      t.references :resolved_by_session, foreign_key: { to_table: :exercise_sessions, on_delete: :restrict }
      t.timestamps
      t.index [ :student_id, :essential_id ], unique: true, where: "status = 'pending'",
                                              name: "index_knowledge_gaps_one_pending"
    end

    add_check_constraint :knowledge_gaps, "status IN ('pending','remediated','self_corrected')", name: "knowledge_gaps_status_values"

    add_foreign_key :exercise_sessions, :knowledge_gaps, on_delete: :restrict
  end
end
