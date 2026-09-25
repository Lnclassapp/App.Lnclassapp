# ADR-0035, ADR-0039 : courses, draft → published → archived. Action Text is gone (ADR-0051):
# the content is a text column. The duplicate key of the imports is enforced by two partial
# indexes, since PostgreSQL 14 has no NULLS NOT DISTINCT.
class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :name, limit: 200, null: false
      t.string :subtitle, limit: 150
      t.text :content
      t.references :level, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.references :material, null: false, foreign_key: { on_delete: :restrict }
      t.references :series, foreign_key: { on_delete: :restrict }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :status, null: false, default: "draft", index: true
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
      t.index [ :level_id, :material_id, :name ], unique: true, where: "series_id IS NULL",
                                                  name: "index_courses_unique_without_series"
      t.index [ :level_id, :material_id, :series_id, :name ], unique: true, where: "series_id IS NOT NULL",
                                                              name: "index_courses_unique_with_series"
    end

    add_check_constraint :courses, "status IN ('draft','published','archived')", name: "courses_status_values"
  end
end
