# ADR-0031, ADR-0050 : server-side sessions, revocable, cascaded with the account (ADR-0036).
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, limit: 64, null: false, index: { unique: true }
      t.string :ip_address, limit: 45
      t.string :user_agent, limit: 255
      t.datetime :created_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :second_factor_verified_at
    end
  end
end
