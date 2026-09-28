# ADR-0044 §6, ADR-0066: the direction of a school — one active school per member, one active principal per school.
# Nothing is ever deleted: a member who leaves gets left_at.
class CreateSchoolStaffs < ActiveRecord::Migration[8.1]
  def change
    create_table :school_staffs do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.references :school, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.string :position, null: false
      t.references :invited_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :joined_at, null: false
      t.datetime :left_at
      t.check_constraint "position IN ('principal', 'censor', 'educator', 'secretary')", name: "school_staffs_position_values"
      t.index :user_id, unique: true, where: "left_at IS NULL", name: "index_school_staffs_one_active_school"
      t.index :school_id, unique: true, where: "position = 'principal' AND left_at IS NULL", name: "index_school_staffs_one_principal"
      t.index %i[school_id left_at]
    end
  end
end
