# ADR-0033, ADR-0043, ADR-0048, ADR-0054 : a student's run through an exercise.
# The foreign key to knowledge_gaps is added once that table exists (create_knowledge_gaps).
class CreateExerciseSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :exercise_sessions do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :exercise, null: false, foreign_key: { on_delete: :restrict }
      t.string :status, null: false, default: "started"
      t.integer :question_count, null: false
      t.integer :answered_count, null: false, default: 0
      t.integer :correct_count, null: false, default: 0
      t.integer :progress_percent, null: false, default: 0
      t.integer :score_percent
      t.string :kind, null: false, default: "standard"
      t.bigint :knowledge_gap_id, index: true
      t.references :classroom_assignment, foreign_key: { on_delete: :restrict }
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.timestamps
      t.index [ :student_id, :exercise_id ], unique: true, where: "status = 'started'",
                                             name: "index_exercise_sessions_one_started"
      t.index [ :student_id, :completed_at ]
    end

    add_check_constraint :exercise_sessions, "status IN ('started','completed','abandoned')", name: "exercise_sessions_status_values"
    add_check_constraint :exercise_sessions, "question_count > 0", name: "exercise_sessions_question_count_positive"
    add_check_constraint :exercise_sessions, "progress_percent BETWEEN 0 AND 100", name: "exercise_sessions_progress_percent_range"
    add_check_constraint :exercise_sessions, "score_percent BETWEEN 0 AND 100", name: "exercise_sessions_score_percent_range"
    add_check_constraint :exercise_sessions, "status <> 'completed' OR score_percent IS NOT NULL",
                         name: "exercise_sessions_completed_has_score"
    add_check_constraint :exercise_sessions, "kind IN ('standard','remediation')", name: "exercise_sessions_kind_values"
    add_check_constraint :exercise_sessions, "(kind = 'remediation') = (knowledge_gap_id IS NOT NULL)",
                         name: "exercise_sessions_remediation_iff_gap"
  end
end
