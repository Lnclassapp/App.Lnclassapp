# ADR-0051 : Action Text is removed until a screen needs rich text; its table goes with it.
class DropActionTextTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :action_text_rich_texts, if_exists: true do |t|
      t.text :body
      t.string :name, null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.timestamps
      t.index [ :record_type, :record_id, :name ], name: "index_action_text_rich_texts_uniqueness", unique: true
    end
  end
end
