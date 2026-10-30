# ADR-XXXX sujets-de-devoir §6 (prepare-interros-cahier, Lot 0) : le sujet de devoir d'une leçon ; ses exercices n'ont pas de notion.
class CreateSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :subjects do |t|
      t.references :course, null: false, foreign_key: { on_delete: :restrict }
      t.integer :position, null: false
      t.string :title, null: false, limit: 200
      t.text :notions, null: false
      t.timestamps
    end
    add_index :subjects, %i[course_id position], unique: true
    add_check_constraint :subjects, "char_length(btrim(title)) >= 1", name: "subjects_title_present"
    add_check_constraint :subjects, "char_length(btrim(notions)) BETWEEN 1 AND 600", name: "subjects_notions_length"

    add_reference :exercises, :subject, foreign_key: { on_delete: :restrict }, index: true
    add_check_constraint :exercises, "subject_id IS NULL OR essential_id IS NULL", name: "exercises_subject_without_essential"
  end
end
