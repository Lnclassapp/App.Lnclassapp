# Owner's decision : the rich text editor is back (Action Text + Trix) for course and
# essential content. V0 dropped these tables (20260925000004); they return as Rails ships them.
class RestoreActionTextTables < ActiveRecord::Migration[8.1]
  def change
    create_table :action_text_rich_texts do |t|
      t.string :name, null: false
      t.text :body
      t.references :record, null: false, polymorphic: true, index: false
      t.timestamps
      t.index [ :record_type, :record_id, :name ], name: "index_action_text_rich_texts_uniqueness", unique: true
    end
  end
end
