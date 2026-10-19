# ADR-0094 §4.1, chantier multi-etablissements-enseignant : l'établissement courant d'une session d'enseignant. NULL : son
# établissement principal. Un établissement supprimé remet la session sur le principal (ON DELETE SET NULL). Pas d'index :
# la session est toujours lue par l'empreinte de son jeton. Rejouable dans les deux sens.
class AddCurrentSchoolIdToSessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :sessions, :current_school, null: true, index: false,
                                              foreign_key: { to_table: :schools, on_delete: :nullify }
  end
end
