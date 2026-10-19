# ADR-0103 §4.6, temps 2 (Lot Z, chantier enseignant-plusieurs-matieres) : plus aucune lecture ni écriture ne cite
# teacher_profiles.material_id ; les matières vivent dans teacher_school_materials. Réversible : `down` rajoute la colonne,
# nullable, remplie avec la première matière de l'établissement principal, à défaut de sa liste la plus ancienne.
class RemoveMaterialIdFromTeacherProfiles < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :teacher_profiles, :materials
    remove_index :teacher_profiles, :material_id
    remove_column :teacher_profiles, :material_id
  end

  def down
    add_reference :teacher_profiles, :material, foreign_key: { on_delete: :restrict }, index: true
    execute <<~SQL.squish
      UPDATE teacher_profiles SET material_id = (
        SELECT tsm.material_id FROM teacher_school_materials tsm
        LEFT JOIN teacher_schools ts ON ts.teacher_id = tsm.teacher_id AND ts.school_id = tsm.school_id
        WHERE tsm.teacher_id = teacher_profiles.user_id
        ORDER BY ts.primary DESC NULLS LAST, tsm.created_at, tsm.id LIMIT 1
      )
    SQL
  end
end
