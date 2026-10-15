# ADR-0090 §4.1, chantier cours-eleve : une ligne par fiche ouverte par un élève, d'où se déduisent « Commencer »,
# « Reprendre » (la dernière fiche ouverte) et « Revoir » sur la page Cours. L'élève ne part pas sous ses lectures
# (restrict : l'anonymisation les efface d'abord, ADR-0036) ; une fiche supprimée emporte les siennes.
class CreateEssentialReads < ActiveRecord::Migration[8.1]
  def change
    create_table :essential_reads do |t|
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.references :essential, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :first_read_at, null: false
      t.datetime :last_read_at, null: false
      t.timestamps
    end
    add_index :essential_reads, %i[student_id essential_id], unique: true
    add_index :essential_reads, %i[student_id last_read_at]
  end
end
