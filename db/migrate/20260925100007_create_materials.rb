# ADR-0034, CA-26 : subjects; the category carries the icon and the colour.
class CreateMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :materials do |t|
      t.string :name, limit: 40, null: false, index: { unique: true }
      t.string :shortname, limit: 10, null: false, index: { unique: true }
      t.string :slug, null: false, index: { unique: true }
      t.string :category, null: false
      t.timestamps
    end

    add_check_constraint :materials, "category IN ('literature','science','other')", name: "materials_category_values"
  end
end
