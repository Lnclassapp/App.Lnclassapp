require "test_helper"

# Lot D (UDR partage-de-classe §3.2) : le kit d'établissement, une feuille par classe ouverte de l'année.
class Classroom::SchoolPostersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @sixth = create_level(name: "Niveau A", position: 901)
    @third = create_level(name: "Niveau B", position: 904)
    @open_classrooms = [ create_classroom(school: @school, level: @third, name: "3e 1"),
                         create_classroom(school: @school, level: @sixth, name: "6e 2"),
                         create_classroom(school: @school, level: @sixth, name: "6e 1") ]
    create_classroom(school: @school, level: @sixth, name: "6e 0", status: "archived")
    create_classroom(school: @school, level: @sixth, name: "6e 9", school_year: "2020-2021")
  end

  test "la direction imprime une feuille par classe ouverte, triées par niveau puis nom" do
    sign_in_as create_school_admin(school: @school)

    get school_posters_path(@school.public_id)

    assert_response :success
    assert_select "article", 3
    assert_equal [ "6e 1", "6e 2", "3e 1" ], css_select("article h2").map { it.text.strip }
    assert_select "figure[role=img] svg", 3
    assert_select "button[data-action='print#print']"
    @open_classrooms.each { |classroom| assert_includes response.body, join_qr_svg_for(classroom.reload.link_token) }
  end

  test "un enseignant de l'établissement reçoit 404" do
    sign_in_as create_teacher(school: @school, classrooms: [ create_classroom(school: @school, name: "5e 1") ])

    get school_posters_path(@school.public_id)

    assert_response :not_found
  end

  test "un élève est refusé sur la route sans identifiant" do
    sign_in_as create_student(classroom: create_classroom(school: @school, name: "2nde 1"))

    get school_admin_posters_path

    assert_response :forbidden
  end

  test "la direction d'un autre établissement reçoit 404" do
    sign_in_as create_school_admin(school: create_school)

    get school_posters_path(@school.public_id)

    assert_response :not_found
  end

  test "l'équipe imprime le kit de tout établissement" do
    sign_in_as create_team_member

    get school_posters_path(@school.public_id)

    assert_response :success
    assert_select "article", 3
  end

  test "un élève reçoit 403" do
    sign_in_as create_student(classroom: create_classroom(school: @school, name: "2nde 1"))

    get school_posters_path(@school.public_id)

    assert_response :forbidden
  end

  test "sans classe ouverte : le dit, sans bouton Imprimer" do
    sign_in_as create_team_member

    get school_posters_path(create_school.public_id)

    assert_response :success
    assert_select "p", text: I18n.t("classroom.school_posters.show.empty")
    assert_select "button[data-action='print#print']", 0
  end

  test "la direction ouvre son kit par la route sans identifiant ; un enseignant y est refusé" do
    sign_in_as create_school_admin(school: @school)
    get school_admin_posters_path
    assert_response :success
    assert_select "article", 3
    assert_not_includes response.body, @school.public_id

    delete session_path
    sign_in_as create_teacher(school: @school, classrooms: [ create_classroom(school: @school, name: "5e 1") ])
    get school_admin_posters_path
    assert_response :not_found
  end
end
