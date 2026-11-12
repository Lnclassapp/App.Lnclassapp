# hors-connexion, Lot B2 (ADR-0133 §4.4, amendement « Devoir à rendre ») : chaque remise du corrigé hors ligne est tracée par élève et exercice.
# Table neuve : l'image précédente l'ignore.
class CreateOfflinePackDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :offline_pack_deliveries do |t|
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :cascade }, index: false
      t.references :exercise, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :first_delivered_at, null: false
      t.datetime :last_delivered_at, null: false
      t.timestamps
      t.index %i[student_id exercise_id], unique: true, name: "index_offline_pack_deliveries_on_student_and_exercise"
    end
  end
end
