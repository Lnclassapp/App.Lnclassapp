# hors-connexion, Lot 0 (ADR §4.5) : une copie rendue hors ligne garde l'identifiant tiré sur l'appareil et l'heure de réception.
# Colonnes nulles (une copie en ligne n'en a pas) : l'image précédente tourne sur ce schéma. L'index unique est posé sans verrou
# d'écriture ; les lignes sans identifiant n'y entrent pas (NULL distincts), donc rien à remplir avant.
class AddOfflineColumnsToExerciseSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :exercise_sessions, :client_copy_id, :uuid, if_not_exists: true
    add_column :exercise_sessions, :received_at, :datetime, if_not_exists: true
    add_index :exercise_sessions, %i[student_id client_copy_id], unique: true, name: "index_exercise_sessions_on_student_and_client_copy",
                                                                 algorithm: :concurrently, if_not_exists: true
  end
end
