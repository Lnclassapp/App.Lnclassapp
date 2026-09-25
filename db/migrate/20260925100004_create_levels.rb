# ADR-0034 : school levels; the frozen slug is the code of the classroom plan (ADR-0030).
class CreateLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :levels do |t|
      t.string :name, limit: 20, null: false, index: { unique: true }
      t.string :slug, null: false, index: { unique: true }
      t.integer :position, null: false, index: { unique: true }
      t.string :cycle, null: false
      t.timestamps
    end

    add_check_constraint :levels, "cycle IN ('first','second')", name: "levels_cycle_values"
  end
end
