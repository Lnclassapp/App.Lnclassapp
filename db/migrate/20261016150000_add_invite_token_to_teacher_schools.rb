# ADR-0094 §11 (réponse MET-8 du porteur), chantier multi-etablissements-enseignant : le lien « Inviter un collègue de mon
# établissement » est celui du rattachement enseignant-établissement, un jeton par ligne teacher_schools ; le jeton du profil
# (teacher_profiles.referral_token) devient le lien de parrainage, sans établissement. Même tirage que les autres jetons
# (48 bits d'un UUID v4, ADR-0063) : le défaut volatil remplit chaque ligne existante en une réécriture de la table, petite.
# Rejouable dans les deux sens.
class AddInviteTokenToTeacherSchools < ActiveRecord::Migration[8.1]
  TOKEN_DEFAULT = "substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)".freeze

  def change
    add_column :teacher_schools, :invite_token, :string, limit: 12, null: false, default: -> { TOKEN_DEFAULT }
    add_index :teacher_schools, :invite_token, unique: true
    add_check_constraint :teacher_schools, "invite_token ~ '^[0-9a-f]{12}$'", name: "teacher_schools_invite_token_format"
  end
end
