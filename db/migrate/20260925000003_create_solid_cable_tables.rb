# ADR-0010 / ADR-0052 : the Solid Suite tables live in the primary database,
# created by a migration instead of a separate db/cable_schema.rb that nothing loads.
class CreateSolidCableTables < ActiveRecord::Migration[8.1]
  def change
    create_table "solid_cable_messages" do |t|
      t.binary "channel", limit: 1024, null: false
      t.binary "payload", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "channel_hash", limit: 8, null: false
      t.index [ "channel" ], name: "index_solid_cable_messages_on_channel"
      t.index [ "channel_hash" ], name: "index_solid_cable_messages_on_channel_hash"
      t.index [ "created_at" ], name: "index_solid_cable_messages_on_created_at"
    end
  end
end
