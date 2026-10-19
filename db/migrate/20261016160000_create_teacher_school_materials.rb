# ADR-0103 §4.6, temps 1 (chantier enseignant-plusieurs-matieres) : les matières d'un enseignant sont celles d'un
# rattachement enseignant-établissement (réponse du porteur du 2026-10-16, point d'extension de l'ADR-0094 §10). Clé du
# rattachement (teacher_id, school_id), sans FK vers teacher_schools : la liste survit à un retrait et revient avec lui.
# Copie de teacher_profiles.material_id pour CHAQUE rattachement, puis pour chaque retrait encore ouvert et chaque demande
# en attente (l'établissement demandé) ; la colonne reste, écrite en double, jusqu'au Lot Z. Rejouable dans les deux sens.
class CreateTeacherSchoolMaterials < ActiveRecord::Migration[8.1]
  def up
    create_table :teacher_school_materials do |t|
      t.bigint :teacher_id, null: false
      t.bigint :school_id, null: false
      t.bigint :material_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :teacher_school_materials, %i[teacher_id school_id material_id], unique: true,
                                                                               name: "index_teacher_school_materials_unique"
    add_index :teacher_school_materials, :school_id
    add_index :teacher_school_materials, :material_id
    add_foreign_key :teacher_school_materials, :users, column: :teacher_id, on_delete: :restrict
    add_foreign_key :teacher_school_materials, :schools, on_delete: :restrict
    add_foreign_key :teacher_school_materials, :materials, on_delete: :restrict

    execute <<~SQL.squish
      INSERT INTO teacher_school_materials (teacher_id, school_id, material_id, created_at)
      SELECT teacher_schools.teacher_id, teacher_schools.school_id, teacher_profiles.material_id, teacher_schools.created_at
      FROM teacher_schools JOIN teacher_profiles ON teacher_profiles.user_id = teacher_schools.teacher_id
      ON CONFLICT DO NOTHING
    SQL
    execute <<~SQL.squish
      INSERT INTO teacher_school_materials (teacher_id, school_id, material_id, created_at)
      SELECT teacher_school_departures.teacher_id, teacher_school_departures.school_id, teacher_profiles.material_id,
             teacher_school_departures.detached_at
      FROM teacher_school_departures JOIN teacher_profiles ON teacher_profiles.user_id = teacher_school_departures.teacher_id
      WHERE teacher_school_departures.reinstated_at IS NULL
      ON CONFLICT DO NOTHING
    SQL
    execute <<~SQL.squish
      INSERT INTO teacher_school_materials (teacher_id, school_id, material_id, created_at)
      SELECT school_join_requests.teacher_id, school_join_requests.school_id, teacher_profiles.material_id,
             school_join_requests.created_at
      FROM school_join_requests JOIN teacher_profiles ON teacher_profiles.user_id = school_join_requests.teacher_id
      WHERE school_join_requests.status = 'pending'
      ON CONFLICT DO NOTHING
    SQL
  end

  def down = drop_table(:teacher_school_materials)
end
