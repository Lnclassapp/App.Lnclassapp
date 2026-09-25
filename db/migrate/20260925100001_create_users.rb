# ADR-0029, ADR-0036, ADR-0037, ADR-0038, ADR-0050 : accounts of every role.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.string :last_name, limit: 50, null: false
      t.string :first_name, limit: 80, null: false
      t.string :contact, limit: 10, index: { unique: true, where: "contact IS NOT NULL" }
      t.string :gender, null: false
      t.string :role, null: false, index: true
      t.string :team_role
      t.string :pin_digest, null: false
      t.datetime :anonymized_at
      t.timestamps
    end

    add_check_constraint :users, "contact ~ '^0[157][0-9]{8}$'", name: "users_contact_format"
    add_check_constraint :users, "gender IN ('male','female')", name: "users_gender_values"
    add_check_constraint :users, "role IN ('student','teacher','school_admin','team')", name: "users_role_values"
    add_check_constraint :users, "team_role IN ('admin','content','field')", name: "users_team_role_values"
    add_check_constraint :users, "(role = 'team') = (team_role IS NOT NULL)", name: "users_team_role_iff_team"
  end
end
