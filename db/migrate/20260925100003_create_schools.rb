# ADR-0030, ADR-0036 : schools; a mixed school follows the private plan.
class CreateSchools < ActiveRecord::Migration[8.1]
  def change
    create_table :schools do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :drena, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, limit: 150, null: false
      t.string :sigle, limit: 20
      t.string :school_type, null: false
      t.string :cycle, null: false, default: "both"
      t.string :status, null: false, default: "active"
      t.timestamps
      t.index [ :drena_id, :name ], unique: true
    end

    add_check_constraint :schools, "school_type IN ('public','private','mixed')", name: "schools_school_type_values"
    add_check_constraint :schools, "cycle IN ('first','both')", name: "schools_cycle_values"
    add_check_constraint :schools, "status IN ('draft','active','inactive')", name: "schools_status_values"
  end
end
