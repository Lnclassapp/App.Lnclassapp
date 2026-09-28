# ADR-0058: the barème of the classrooms generated for a school, one entry per school type (mixed follows private),
# level and series (nil on the first cycle). The foreign keys restrict (ADR-0036): the taxonomy repository deletes the
# entries of a level or a series with it. The two partial unique indexes stand in for NULLS NOT DISTINCT (PostgreSQL 15+).
class CreateClassroomPlanEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :classroom_plan_entries do |t|
      t.string :school_type, null: false
      t.references :level, null: false, index: false, foreign_key: { on_delete: :restrict }
      t.references :series, null: true, foreign_key: { on_delete: :restrict }
      t.integer :count, null: false
      t.timestamps
    end
    add_check_constraint :classroom_plan_entries, "school_type IN ('public','private')", name: "classroom_plan_entries_school_type_values"
    add_check_constraint :classroom_plan_entries, "count BETWEEN 0 AND 30", name: "classroom_plan_entries_count_range"
    add_index :classroom_plan_entries, %i[school_type level_id series_id], unique: true, where: "series_id IS NOT NULL",
                                                                           name: "index_classroom_plan_entries_on_pair"
    add_index :classroom_plan_entries, %i[school_type level_id], unique: true, where: "series_id IS NULL",
                                                                 name: "index_classroom_plan_entries_on_level"
  end
end
