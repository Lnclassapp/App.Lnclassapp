require "test_helper"

# TR-cadre-4 (PRD cadre §5) — un enseignant qui n'enseigne pas dans une classe en est refusé, et la réponse ne livre ni le
# code d'adhésion ni le nom d'un élève de cette classe. Vrai aussi pour un collègue du même établissement.
class Classroom::ForeignTeacherAccessTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @classroom = create_classroom(school: @school, name: "3ème B")
    create_teacher(school: @school, classrooms: [ @classroom ])
    create_student(classroom: @classroom, first_name: "Mariam", last_name: "Traoré")
  end

  def assert_refused_without_classroom_data
    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_no_match(/kfm37|Mariam|Traoré|3ème B/i, response.body)
  end

  test "un enseignant d'un autre établissement est refusé, sans code ni nom d'élève" do
    sign_in_as create_teacher(classrooms: [ create_classroom ])

    assert_refused_without_classroom_data
  end

  test "un collègue du même établissement qui n'enseigne pas en 3ème B est refusé de même" do
    sign_in_as create_teacher(school: @school, classrooms: [ create_classroom(school: @school) ])

    assert_refused_without_classroom_data
  end

  test "un enseignant qui a quitté la classe n'y a plus accès" do
    former = create_teacher(school: @school, classrooms: [ @classroom ])
    Orm::TeacherClassroom.where(teacher: former).delete_all
    sign_in_as former

    assert_refused_without_classroom_data
  end
end
