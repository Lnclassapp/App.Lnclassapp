# ADR-0035, ADR-0054 : exercises of an essential sheet, addressed by public_id (ADR-0029).
class CreateExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :exercises do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :essential, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.string :title, limit: 200, null: false
      t.text :description
      t.string :exercise_type, null: false, default: "fixation"
      t.integer :position, null: false
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :status, null: false, default: "draft", index: true
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
      t.index [ :essential_id, :position ], unique: true
      t.index [ :essential_id, :status ]
    end

    add_check_constraint :exercises, "exercise_type IN ('fixation','evaluation')", name: "exercises_exercise_type_values"
    add_check_constraint :exercises, "status IN ('draft','published','archived')", name: "exercises_status_values"
  end
end
