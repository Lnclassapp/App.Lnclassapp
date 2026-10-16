require "test_helper"

# ADR-0094 §4.6 : les établissements d'un enseignant pour le panneau du compte et « Mes établissements », en une requête.
class Queries::School::TeacherSchoolsQueryTest < ActiveSupport::TestCase
  def schools(teacher, current_school_id: nil) = Queries::School::TeacherSchoolsQuery.new.call(teacher_id: teacher.id, current_school_id:)

  test "lists the teacher's schools, primary first then by attachment date, with their DRENA and the current one" do
    abobo = create_drena(name: "DRENA Abidjan 2")
    bouake = create_drena(name: "DRENA Bouaké 1")
    primary = create_school(drena: abobo, name: "Lycée moderne d'Abobo", sigle: "LMA")
    older = create_school(drena: bouake, name: "Collège Saint-Michel")
    newer = create_school(drena: abobo, name: "Collège Notre-Dame")
    teacher = create_teacher(school: nil)
    at = Time.zone.parse("2026-10-01 08:00")
    Orm::TeacherSchool.create!(teacher:, school: newer, primary: false, created_at: at + 2.days)
    Orm::TeacherSchool.create!(teacher:, school: primary, primary: true, created_at: at + 1.day)
    Orm::TeacherSchool.create!(teacher:, school: older, primary: false, created_at: at)
    create_teacher(school: create_school)

    rows = schools(teacher, current_school_id: older.id)

    assert_equal [ [ primary.public_id, "Lycée moderne d'Abobo", "LMA", "DRENA Abidjan 2", true, false ],
                   [ older.public_id, "Collège Saint-Michel", nil, "DRENA Bouaké 1", false, true ],
                   [ newer.public_id, "Collège Notre-Dame", nil, "DRENA Abidjan 2", false, false ] ],
                 rows.map { [ it.public_id, it.name, it.sigle, it.drena_name, it.primary, it.current ] }
  end

  test "reads nothing else: no database identifier" do
    assert_equal %i[public_id name sigle drena_name primary current], Queries::School::TeacherSchoolsQuery::Row.members
  end

  test "a teacher without school has none, in one query" do
    teacher = create_teacher(school: nil)

    assert_queries_count(1) { assert_empty schools(teacher) }
  end
end
