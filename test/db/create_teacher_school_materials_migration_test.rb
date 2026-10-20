require "test_helper"
require Rails.root.join("db/migrate/20261016160000_create_teacher_school_materials").to_s
require Rails.root.join("db/migrate/20261016170000_remove_material_id_from_teacher_profiles").to_s

# ADR-0103 §4.6 (EPM-01) : sur une base réelle, le temps 1 copie teacher_profiles.material_id pour CHAQUE rattachement
# enseignant-établissement, puis pour chaque retrait encore ouvert et chaque demande en attente ; le temps 2 (Lot Z) retire
# la colonne, et son retour la remplit avec la première matière de l'établissement principal. Un enseignant resté sans
# aucune ligne (demande refusée) garde sa matière sur l'établissement de sa dernière demande. Chaque test tourne dans la
# transaction annulée du test.
class CreateTeacherSchoolMaterialsMigrationTest < ActiveSupport::TestCase
  def migrate(migration, direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { migration.new.migrate(direction) }
    end
    Orm::TeacherProfile.reset_column_information
  end

  teardown { Orm::TeacherProfile.reset_column_information }

  def profile_material(teacher) = Orm::TeacherProfile.where(user_id: teacher.id).pick(:material_id)

  test "one row per attachment, open departure and pending request, with the subject of the profile; the column goes, and comes back" do
    svt, pc = create_material(name: "SVT"), create_material(name: "Physique-Chimie")
    a, b, left, back = create_school, create_school, create_school, create_school
    two = create_teacher(school: a, material: svt)
    add_teacher_school(two, b)
    one = create_teacher(school: a, material: pc)
    create_teacher_departure(teacher: one, school: left, detached_by: create_school_admin(school: left))
    create_teacher_departure(teacher: one, school: back, detached_by: create_school_admin(school: back), reinstated: true)
    waiting = create_teacher(school: nil)
    create_join_request(school: back, teacher: waiting)
    pending = create_teacher(school: nil)
    refused = create_teacher(school: nil)
    create_join_request(school: left, teacher: refused, status: "rejected")
    rejoined = create_teacher(school: a, material: svt)
    create_join_request(school: back, teacher: rejoined, status: "rejected")

    migrate(RemoveMaterialIdFromTeacherProfiles, :down)
    assert_equal [ svt.id, pc.id, nil ], [ two, one, waiting ].map { profile_material(it) }, "le retour remplit la colonne"
    Orm::TeacherProfile.where(user_id: waiting.id).update_all(material_id: svt.id)
    Orm::TeacherProfile.where(user_id: pending.id).update_all(material_id: pc.id)
    Orm::TeacherProfile.where(user_id: refused.id).update_all(material_id: pc.id)
    migrate(CreateTeacherSchoolMaterials, :down)
    migrate(CreateTeacherSchoolMaterials, :up)

    rows = Orm::TeacherSchoolMaterial.pluck(:teacher_id, :school_id, :material_id)
    assert_equal [ [ two.id, a.id, svt.id ], [ two.id, b.id, svt.id ], [ one.id, a.id, pc.id ], [ one.id, left.id, pc.id ],
                   [ waiting.id, back.id, svt.id ], [ rejoined.id, a.id, svt.id ], [ refused.id, left.id, pc.id ] ].sort, rows.sort,
                 "la demande refusée ne laisse une ligne que si l'enseignant n'a rien d'autre"
    assert_not Orm::TeacherSchoolMaterial.exists?(teacher_id: pending.id), "sans rattachement, retrait ni demande : rien à copier"

    Orm::TeacherProfile.where(user_id: pending.id).update_all(material_id: nil)
    migrate(RemoveMaterialIdFromTeacherProfiles, :up)
    assert_not_includes Orm::TeacherProfile.column_names, "material_id"
  end

  test "the column comes back with the subject of the primary school, not of an older secondary school" do
    svt, pc = create_material(name: "SVT"), create_material(name: "Physique-Chimie")
    primary, older = create_school, create_school
    teacher = create_teacher(school: primary, material: svt)
    add_teacher_school(teacher, older, materials: [ pc ], at: 1.year.ago)

    migrate(RemoveMaterialIdFromTeacherProfiles, :down)

    assert_equal svt.id, profile_material(teacher)
    migrate(RemoveMaterialIdFromTeacherProfiles, :up)
  end
end
