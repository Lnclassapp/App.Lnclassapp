# ADR-0072 §4.2: the weekdays (1 = Monday … 6 = Saturday, as Date#cwday) a teacher sees a classroom he declared.
# No row means "not answered yet". A session day exists only for a declared classroom (composite key, RESTRICT): the
# teaching repository removes the days before the declaration. teacher_id also references users, as every person column.
class CreateClassroomSessionDays < ActiveRecord::Migration[8.1]
  def change
    create_table :classroom_session_days do |t|
      t.bigint :teacher_id, null: false
      t.bigint :classroom_id, null: false
      t.integer :weekday, limit: 2, null: false
      t.datetime :created_at, null: false
      t.check_constraint "weekday BETWEEN 1 AND 6", name: "classroom_session_days_weekday_range"
      t.index %i[teacher_id classroom_id weekday], unique: true, name: "index_classroom_session_days_unique"
      t.index :classroom_id
    end
    add_foreign_key :classroom_session_days, :users, column: :teacher_id, on_delete: :restrict
    add_foreign_key :classroom_session_days, :teacher_classrooms, column: %i[teacher_id classroom_id],
                                                                   primary_key: %i[teacher_id classroom_id], on_delete: :restrict
  end
end
