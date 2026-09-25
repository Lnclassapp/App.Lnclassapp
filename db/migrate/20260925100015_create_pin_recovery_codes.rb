# ADR-0032 : assisted PIN recovery, one active code per account.
class CreatePinRecoveryCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :pin_recovery_codes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade },
                          index: { unique: true, where: "used_at IS NULL AND revoked_at IS NULL",
                                   name: "index_pin_recovery_codes_one_active" }
      t.references :issued_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :code_digest, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :used_at
      t.datetime :revoked_at
      t.datetime :created_at, null: false
    end
  end
end
