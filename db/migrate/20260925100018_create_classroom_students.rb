# ADR-0040 : memberships, one active primary classroom per student; a membership is never deleted.
class CreateClassroomStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :classroom_students do |t|
      t.references :classroom, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.boolean :primary, null: false, default: false
      t.datetime :joined_at, null: false
      t.datetime :left_at
      t.index [ :classroom_id, :student_id ], unique: true
      t.index :student_id, unique: true, where: '"primary" AND left_at IS NULL',
                           name: "index_classroom_students_one_active_primary"
    end
  end
end
