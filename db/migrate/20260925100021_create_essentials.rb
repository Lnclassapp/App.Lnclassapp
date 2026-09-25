# ADR-0035 : essential sheets of a course, same life cycle as the course.
class CreateEssentials < ActiveRecord::Migration[8.1]
  def change
    create_table :essentials do |t|
      t.references :course, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.string :slug, null: false, index: { unique: true }
      t.string :name, limit: 150, null: false
      t.string :subtitle, limit: 150
      t.text :content
      t.integer :position, null: false
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :status, null: false, default: "draft", index: true
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
      t.index [ :course_id, :name ], unique: true
      t.index [ :course_id, :position ], unique: true
    end

    add_check_constraint :essentials, "status IN ('draft','published','archived')", name: "essentials_status_values"
  end
end
