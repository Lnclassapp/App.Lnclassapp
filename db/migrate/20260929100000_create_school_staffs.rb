# ADR-0065: a school admin account is attached to one school (unique user_id), without position nor departure date;
# a school staff invitation needs a school, no longer a position (amendment of ADR-0044).
class CreateSchoolStaffs < ActiveRecord::Migration[8.1]
  def change
    create_table :school_staffs do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :restrict }
      t.references :invited_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :created_at, null: false
    end
    remove_check_constraint :invitations, "kind <> 'school_staff' OR (school_id IS NOT NULL AND position IS NOT NULL)",
                            name: "invitations_staff_has_school"
    add_check_constraint :invitations, "kind <> 'school_staff' OR school_id IS NOT NULL", name: "invitations_staff_has_school"
  end
end
