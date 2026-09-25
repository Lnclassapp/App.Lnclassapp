# ADR-0030 : a teacher's school, one primary school at most.
class CreateTeacherSchools < ActiveRecord::Migration[8.1]
  def change
    create_table :teacher_schools do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :school, null: false, foreign_key: { on_delete: :restrict }
      t.boolean :primary, null: false, default: false
      t.datetime :created_at, null: false
      t.index [ :teacher_id, :school_id ], unique: true
      t.index :teacher_id, unique: true, where: '"primary"', name: "index_teacher_schools_one_primary"
    end
  end
end
