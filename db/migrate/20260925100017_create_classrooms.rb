# ADR-0041 : classrooms of a school year, archived at its end, with a revocable join code.
# The join code column is exactly as long as the generated code (classroom-code-adhesion-trop-long).
class CreateClassrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :classrooms do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.references :level, null: false, foreign_key: { on_delete: :restrict }
      t.references :series, foreign_key: { on_delete: :restrict }
      t.string :name, limit: 15, null: false
      t.string :school_year, limit: 9, null: false
      t.string :status, null: false, default: "active"
      t.datetime :archived_at
      t.string :join_code, limit: 5, index: { unique: true, where: "join_code IS NOT NULL" }
      t.datetime :join_code_rotated_at
      t.integer :max_students, null: false, default: 80
      t.timestamps
      t.index [ :school_id, :school_year, :name ], unique: true
    end

    add_check_constraint :classrooms,
                         "school_year ~ '^[0-9]{4}-[0-9]{4}$' AND right(school_year, 4)::int = left(school_year, 4)::int + 1",
                         name: "classrooms_school_year_format"
    add_check_constraint :classrooms, "status IN ('active','archived')", name: "classrooms_status_values"
    add_check_constraint :classrooms, "(status = 'archived') = (archived_at IS NOT NULL)", name: "classrooms_archived_at_iff_archived"
    add_check_constraint :classrooms, "join_code ~ '^[a-hj-np-z]{3}[2-9]{2}$'", name: "classrooms_join_code_format"
    add_check_constraint :classrooms, "max_students BETWEEN 1 AND 150", name: "classrooms_max_students_range"
  end
end
