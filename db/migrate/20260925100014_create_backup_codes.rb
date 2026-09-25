# ADR-0031 : single-use backup codes, stored as HMAC-SHA256 only.
class CreateBackupCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_codes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { where: "used_at IS NULL" }
      t.string :code_digest, limit: 64, null: false
      t.datetime :used_at
      t.datetime :created_at, null: false
    end
  end
end
