# ADR-0089 §4.2, Lot 0 of images-dans-les-cours: a sheet (catalog) and a question (assessment) carry checked images
# without metadata, at most 300 KB and 1200 px a side. NULL owner between upload and the first save that cites them.
# A question has at most one image (partial unique index). Nothing is deleted through a foreign key (RESTRICT, ADR-0036):
# the store detaches and destroys an image before its question or sheet goes. The import announces a question's image by its description.
class CreateEssentialAndQuestionImages < ActiveRecord::Migration[8.1]
  def change
    create_table :essential_images do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :essential, foreign_key: { on_delete: :restrict }
      t.string :alt, limit: 150
      t.string :content_type, null: false
      t.integer :byte_size, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.timestamps
      t.check_constraint "content_type IN ('image/jpeg','image/png','image/webp')", name: "essential_images_content_type_values"
      t.check_constraint "byte_size BETWEEN 1 AND 307200", name: "essential_images_byte_size"
      t.check_constraint "width BETWEEN 1 AND 1200 AND height BETWEEN 1 AND 1200", name: "essential_images_sides"
    end

    create_table :question_images do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :question, foreign_key: { on_delete: :restrict }, index: { unique: true, where: "question_id IS NOT NULL" }
      t.string :alt, limit: 150
      t.string :content_type, null: false
      t.integer :byte_size, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.timestamps
      t.check_constraint "content_type IN ('image/jpeg','image/png','image/webp')", name: "question_images_content_type_values"
      t.check_constraint "byte_size BETWEEN 1 AND 307200", name: "question_images_byte_size"
      t.check_constraint "width BETWEEN 1 AND 1200 AND height BETWEEN 1 AND 1200", name: "question_images_sides"
    end

    add_column :questions, :image_description, :string, limit: 150
    add_check_constraint :questions, "image_description IS NULL OR char_length(btrim(image_description)) >= 1",
                         name: "questions_image_description_present"
  end
end
