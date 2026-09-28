# ADR-0066 §4.4: a teacher detached from a school by its direction; the departure is open until a reinstatement closes
# it (both reinstated_at and reinstated_by_id, or neither). One open departure per teacher and school.
class CreateTeacherSchoolDepartures < ActiveRecord::Migration[8.1]
  def change
    create_table :teacher_school_departures do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :school, null: false, foreign_key: { on_delete: :restrict }
      t.references :detached_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :created_at, null: false
      t.datetime :reinstated_at
      t.references :reinstated_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.check_constraint "(reinstated_at IS NULL) = (reinstated_by_id IS NULL)", name: "teacher_school_departures_reinstated_pair"
      t.index %i[teacher_id school_id], unique: true, where: "reinstated_at IS NULL", name: "index_teacher_school_departures_one_open"
    end
  end
end
