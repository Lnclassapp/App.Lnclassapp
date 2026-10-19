# ADR-0092 §4.2, chantier espace-direction : chaque compte de direction a une fonction parmi quatre, obligatoire (réponse
# DIR-4 du porteur : aucune direction n'est inscrite, Lnclass n'est pas lancé) ; un seul chef d'établissement actif par
# établissement (index unique partiel). S'il existait des lignes, elles recevraient « deputy » : rang gestion, donc aucun
# geste perdu, et aucun chef inventé ; l'équipe corrige ensuite la fonction (« Changer la fonction »). Même règle pour une
# invitation de direction en attente, dont les anciennes valeurs (principal, censor) n'ont jamais été écrites (ADR-0044).
# Rejouable dans les deux sens.
class AddPositionToSchoolStaffs < ActiveRecord::Migration[8.1]
  POSITIONS = "position IN ('head', 'deputy', 'educator', 'secretary')".freeze
  OLD_POSITIONS = "position IN ('principal', 'censor', 'educator', 'secretary')".freeze
  FALLBACK = "deputy".freeze

  def up
    unless column_exists?(:school_staffs, :position)
      add_column :school_staffs, :position, :string
      say_with_time "school_staffs sans fonction → #{FALLBACK}" do
        execute("UPDATE school_staffs SET position = '#{FALLBACK}' WHERE position IS NULL").cmd_tuples
      end
      change_column_null :school_staffs, :position, false
      add_check_constraint :school_staffs, POSITIONS, name: "school_staffs_position_values"
      add_index :school_staffs, :school_id, unique: true, where: "position = 'head' AND archived_at IS NULL",
                                            name: "index_school_staffs_one_active_head"
    end
    return if check_constraint_exists?(:invitations, name: "invitations_staff_has_position")

    remove_check_constraint :invitations, name: "invitations_position_values"
    execute "UPDATE invitations SET position = '#{FALLBACK}' WHERE kind = 'school_staff' AND position IS DISTINCT FROM 'educator' " \
            "AND position IS DISTINCT FROM 'secretary'"
    add_check_constraint :invitations, POSITIONS, name: "invitations_position_values"
    add_check_constraint :invitations, "kind <> 'school_staff' OR position IS NOT NULL", name: "invitations_staff_has_position"
  end

  def down
    if check_constraint_exists?(:invitations, name: "invitations_staff_has_position")
      remove_check_constraint :invitations, name: "invitations_staff_has_position"
      remove_check_constraint :invitations, name: "invitations_position_values"
      execute "UPDATE invitations SET position = NULL WHERE position IN ('head', 'deputy')"
      add_check_constraint :invitations, OLD_POSITIONS, name: "invitations_position_values"
    end
    remove_column :school_staffs, :position if column_exists?(:school_staffs, :position)
  end
end
