require "test_helper"

# CA-E10 (mvp-teacher-student, lot O2) : « Mon établissement » lit le nom, le sigle, la DRENA et le type de l'établissement de la
# classe principale de l'élève connecté, par l'identifiant de son compte, jamais par un identifiant reçu.
class Queries::School::StudentSchoolQueryTest < ActiveSupport::TestCase
  def school_of(student_id) = Queries::School::StudentSchoolQuery.new.call(student_id:)

  test "gives the name, acronym, DRENA and type of the school of the student's classroom" do
    school = create_school(name: "Collège Moderne 1 de Tiassalé", sigle: "CM1T", school_type: "private",
                           drena: create_drena(name: "Agboville"))
    student = create_student(classroom: create_classroom(school:))

    row = school_of(student.id)

    assert_equal [ "Collège Moderne 1 de Tiassalé", "CM1T", "Agboville", "private" ],
                 [ row.name, row.sigle, row.drena_name, row.school_type ]
  end

  test "a school without an acronym gives a nil one, not an empty string" do
    student = create_student(classroom: create_classroom(school: create_school(sigle: nil)))

    assert_nil school_of(student.id).sigle
  end

  test "reads nothing else: no identifier of the database, no school code, no invite token, no other school" do
    assert_equal %i[name sigle drena_name school_type], Queries::School::StudentSchoolQuery::Row.members
  end

  test "gives the school of the student's own classroom only, whatever the other schools" do
    mine = create_school(name: "Mon lycée")
    other_student = create_student(classroom: create_classroom(school: create_school(name: "Lycée voisin")))
    student = create_student(classroom: create_classroom(school: mine))

    assert_equal "Mon lycée", school_of(student.id).name
    assert_equal "Lycée voisin", school_of(other_student.id).name
  end

  test "a student without a classroom, or who left it, gives nil" do
    assert_nil school_of(create_student.id)

    left = create_student(classroom: create_classroom)
    Orm::ClassroomStudent.where(student_id: left.id).update_all(left_at: 1.day.ago)

    assert_nil school_of(left.id)
  end

  # Archiving a classroom keeps its memberships open: the status filter, as in the queries of the same screens.
  test "a student whose classroom is archived gives nil" do
    classroom = create_classroom
    student = create_student(classroom:)
    Orm::Classroom.where(id: classroom.id).update_all(status: "archived", archived_at: Time.current)

    assert_nil school_of(student.id)
  end

  test "an unknown or missing identifier gives nil, in one query at most" do
    student = create_student(classroom: create_classroom)

    assert_nil school_of(0)
    assert_queries_count(0) { assert_nil school_of(nil) }
    assert_queries_count(1) { school_of(student.id) }
  end
end
