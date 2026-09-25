# ADR-0050 : append-only audit log, centred on the actor (ADR-0027).
class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :actor, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.string :action, limit: 60, null: false
      t.string :subject_type, limit: 40
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address, limit: 45
      t.datetime :created_at, null: false
      t.index [ :subject_type, :subject_id ]
      t.index [ :actor_id, :created_at ]
    end
  end
end
