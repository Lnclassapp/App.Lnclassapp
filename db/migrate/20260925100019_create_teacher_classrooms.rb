# ADR-0030 : classrooms a teacher declares teaching.
class CreateTeacherClassrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :teacher_classrooms do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :classroom, null: false, foreign_key: { on_delete: :restrict }
      t.datetime :created_at, null: false
      t.index [ :teacher_id, :classroom_id ], unique: true
    end
  end
end
