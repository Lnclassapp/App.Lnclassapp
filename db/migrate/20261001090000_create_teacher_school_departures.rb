# ADR-0071 §4.4: the trace of a teacher withdrawn from a school by its direction. Open until the direction reinstates
# him; while open, the school's code does not take him back. One open departure per teacher and school.
class CreateTeacherSchoolDepartures < ActiveRecord::Migration[8.1]
  def change
    create_table :teacher_school_departures do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :school, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.references :detached_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :detached_at, null: false
      t.references :reinstated_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :reinstated_at
      t.check_constraint "(reinstated_at IS NULL) = (reinstated_by_id IS NULL)", name: "teacher_school_departures_reinstated_together"
      t.index %i[teacher_id school_id], unique: true, where: "reinstated_at IS NULL", name: "index_teacher_school_departures_one_open"
      t.index %i[school_id detached_at]
    end
  end
end
