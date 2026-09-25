# ADR-0031 : TOTP second factor of a team account, secret encrypted by Active Record.
class CreateTotpCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :totp_credentials do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.text :secret, null: false
      t.datetime :confirmed_at
      t.bigint :last_used_step
      t.timestamps
    end
  end
end
