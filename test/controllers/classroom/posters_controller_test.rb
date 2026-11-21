require "test_helper"

# Lot D (UDR partage-de-classe §3.2) : l'affiche A4 d'une classe, pour l'enseignant, la direction et l'équipe.
class Classroom::PostersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, level: create_level, name: "3e 2")
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
  end

  test "l'enseignant de la classe obtient l'A4 : classe, établissement, QR, 3 étapes" do
    sign_in_as @teacher

    get classroom_poster_path(@classroom.public_id)

    assert_response :success
    assert_select "h2", text: "3e 2"
    assert_select "article", text: /Lycée Classique d'Abidjan/
    assert_select "figure[role=img] svg"
    assert_includes response.body, join_qr_svg_for(@classroom.reload.link_token)
    assert_select "ol li", 3
    assert_select "[class~='print:hidden']"
  end

  test "l'équipe et la direction de l'établissement l'obtiennent" do
    sign_in_as create_team_member
    get classroom_poster_path(@classroom.public_id)
    assert_response :success

    delete session_path
    sign_in_as create_school_admin(school: @school)
    get classroom_poster_path(@classroom.public_id)
    assert_response :success
  end

  test "un enseignant d'une autre classe reçoit 404" do
    sign_in_as create_teacher(school: @school, classrooms: [ create_classroom(school: @school, name: "3e 3") ])

    get classroom_poster_path(@classroom.public_id)

    assert_response :not_found
  end

  test "un élève reçoit 403" do
    sign_in_as create_student(classroom: @classroom)

    get classroom_poster_path(@classroom.public_id)

    assert_response :forbidden
  end

  test "une classe archivée reçoit 404" do
    archived = create_classroom(school: @school, name: "4e 1", status: "archived")
    sign_in_as create_team_member

    get classroom_poster_path(archived.public_id)

    assert_response :not_found
  end

  test "une classe inconnue reçoit 404" do
    sign_in_as @teacher

    get classroom_poster_path("inconnue")

    assert_response :not_found
  end
end
