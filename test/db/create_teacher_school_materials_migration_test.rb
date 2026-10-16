require "test_helper"
require Rails.root.join("db/migrate/20261016160000_create_teacher_school_materials").to_s

# ADR-0103 §4.6, temps 1 (EPM-01) : sur une base réelle, la migration copie teacher_profiles.material_id pour CHAQUE
# rattachement enseignant-établissement, puis pour chaque retrait encore ouvert. Chaque test tourne dans la transaction
# annulée du test.
class CreateTeacherSchoolMaterialsMigrationTest < ActiveSupport::TestCase
  def migrate(direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { CreateTeacherSchoolMaterials.new.migrate(direction) }
    end
  end

  test "one row per attachment, with the subject of the profile, and one per open departure" do
    svt, pc = create_material(name: "SVT"), create_material(name: "Physique-Chimie")
    a, b, left, back = create_school, create_school, create_school, create_school
    two = create_teacher(school: a, material: svt)
    add_teacher_school(two, b)
    one = create_teacher(school: a, material: pc)
    create_teacher_departure(teacher: one, school: left, detached_by: create_school_admin(school: left))
    create_teacher_departure(teacher: one, school: back, detached_by: create_school_admin(school: back), reinstated: true)
    pending = create_teacher(school: nil, material: pc)
    expected = Orm::TeacherSchool.count + Orm::TeacherSchoolDeparture.where(reinstated_at: nil).count

    migrate(:down)
    migrate(:up)

    rows = Orm::TeacherSchoolMaterial.pluck(:teacher_id, :school_id, :material_id)
    assert_equal expected, rows.size
    assert_equal [ [ two.id, a.id, svt.id ], [ two.id, b.id, svt.id ], [ one.id, a.id, pc.id ], [ one.id, left.id, pc.id ] ].sort, rows.sort
    assert_not Orm::TeacherSchoolMaterial.exists?(teacher_id: pending.id), "sans rattachement, rien à copier"
  end

  test "the migration reruns both ways" do
    migrate(:down)
    assert_not ActiveRecord::Base.connection.table_exists?(:teacher_school_materials)

    migrate(:up)
    assert ActiveRecord::Base.connection.table_exists?(:teacher_school_materials)
  end
end
