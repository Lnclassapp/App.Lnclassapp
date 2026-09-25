# ADR-0048 : resources assigned to a classroom, archived, never deleted. No foreign key
# on the polymorphic resource: only published content is assignable (ADR-0036).
class CreateClassroomAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :classroom_assignments do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :classroom, null: false, foreign_key: { on_delete: :restrict }
      t.string :assignable_type, null: false
      t.bigint :assignable_id, null: false
      t.references :assigned_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :status, null: false, default: "active"
      t.datetime :assigned_at, null: false
      t.datetime :archived_at
      t.references :archived_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.timestamps
      t.index [ :classroom_id, :assignable_type, :assignable_id ], unique: true, where: "status = 'active'",
                                                                    name: "index_classroom_assignments_one_active"
      t.index [ :assignable_type, :assignable_id ]
    end

    add_check_constraint :classroom_assignments, "assignable_type IN ('Course','Essential','Exercise')",
                         name: "classroom_assignments_type_values"
    add_check_constraint :classroom_assignments, "status IN ('active','archived')", name: "classroom_assignments_status_values"
    add_check_constraint :classroom_assignments, "(status = 'archived') = (archived_at IS NOT NULL)",
                         name: "classroom_assignments_archived_at_iff_archived"
  end
end
