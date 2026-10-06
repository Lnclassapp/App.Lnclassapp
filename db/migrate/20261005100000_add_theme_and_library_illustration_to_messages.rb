# ADR-0081 §4.2 and §4.3, amending ADR-0078 §4.1: an announcement has one of ten themes, "ciel" by default, and exactly
# one illustration: a base key (messages.illustration) or a drawing of the team (messages.illustration_id). The team's
# drawings are kept as their rebuilt shapes, never as the file sent, and are never deleted: a retirement dates them.
# ADR-0081 §4.1: the end of an announcement is computed (publication + 30 days), the 90-day bound leaves the database.
# No announcement exists in production (memo, grill): nothing to take over.
class AddThemeAndLibraryIllustrationToMessages < ActiveRecord::Migration[8.1]
  THEMES = %w[ciel lagune menthe citron mangue corail hibiscus lavande indigo nuit].freeze

  def change
    create_table :message_illustrations do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.string :name, limit: 30, null: false
      t.string :view_box, null: false
      t.jsonb :shapes, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: true
      t.datetime :retired_at
      t.timestamps
      t.check_constraint "btrim(name) <> ''", name: "message_illustrations_name_present"
      t.check_constraint "jsonb_typeof(shapes) = 'array'", name: "message_illustrations_shapes_array"
      # CASE: PostgreSQL does not promise to evaluate the type check first, and jsonb_array_length fails on an object.
      t.check_constraint "CASE WHEN jsonb_typeof(shapes) = 'array' THEN jsonb_array_length(shapes) <= 500 ELSE true END",
                         name: "message_illustrations_shapes_max"
    end

    add_column :messages, :theme, :string, null: false, default: "ciel"
    add_check_constraint :messages, "theme IN (#{THEMES.map { "'#{it}'" }.join(', ')})", name: "messages_theme_values"

    change_column_null :messages, :illustration, true
    add_reference :messages, :illustration, foreign_key: { to_table: :message_illustrations, on_delete: :restrict }, index: true
    add_check_constraint :messages, "num_nonnulls(illustration, illustration_id) = 1", name: "messages_one_illustration"

    remove_check_constraint :messages, "ends_at IS NULL OR published_at IS NULL OR " \
                                       "(ends_at > published_at AND ends_at <= published_at + interval '90 days')",
                            name: "messages_ends_at_window"
    add_check_constraint :messages, "ends_at IS NULL OR published_at IS NULL OR ends_at > published_at",
                         name: "messages_ends_at_window"
  end
end
