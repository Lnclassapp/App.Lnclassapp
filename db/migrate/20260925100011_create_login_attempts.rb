# ADR-0050 : every PIN or second factor attempt, for the progressive lockout.
class CreateLoginAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :login_attempts do |t|
      t.string :contact, limit: 20, null: false
      t.references :user, foreign_key: { on_delete: :cascade }
      t.string :ip_address, limit: 45
      t.boolean :succeeded, null: false
      t.string :kind, null: false
      t.datetime :created_at, null: false
      t.index [ :contact, :created_at ]
    end

    add_check_constraint :login_attempts, "kind IN ('pin','second_factor')", name: "login_attempts_kind_values"
  end
end
