# ADR-0033 : a student's best badge on an exercise.
class CreateExerciseBadges < ActiveRecord::Migration[8.1]
  def change
    create_table :exercise_badges do |t|
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :exercise, null: false, foreign_key: { on_delete: :restrict }
      t.references :exercise_session, null: false, foreign_key: { on_delete: :restrict }
      t.string :level, null: false
      t.datetime :awarded_at, null: false
      t.timestamps
      t.index [ :student_id, :exercise_id ], unique: true
    end

    add_check_constraint :exercise_badges, "level IN ('bronze','silver','gold','diamond')", name: "exercise_badges_level_values"
  end
end
