require "test_helper"

# Lot R of fonctions-espace-eleve (ADR-0036, memo Q19): the school a student left reads, under « Anciens élèves », the
# results he obtained there; a sister page of « Travail des élèves », without any student identifier in the HTML.
class SchoolAdmin::DepartedStudentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @other = create_school(name: "Collège Voltaire")
    @admin = create_school_admin(school: @school)
    @last_year = create_classroom(school: @school, name: "3ème 4", level: create_level(name: "3ème"), status: "archived",
                                  school_year: "2025-2026")
    @awa = create_student(classroom: @last_year, first_name: "Awa", last_name: "Koné")
    exercise = create_exercise
    assignment = create_assignment(classroom: @last_year, assignable: exercise, by: create_teacher(school: @school))
    create_exercise_session(student: @awa, exercise:, status: "completed", score_percent: 72, classroom_assignment_id: assignment.id)
  end

  test "the direction reads its former students, their last classroom and the results obtained in its school" do
    create_student(classroom: create_classroom(school: @other, status: "archived", school_year: "2025-2026"), last_name: "Ailleurs")
    sign_in_as @admin

    get school_admin_departed_students_path

    assert_response :success
    assert_select "title", text: /\AAnciens élèves/
    assert_select "h1", "Anciens élèves"
    assert_select "main nav[aria-label=Retour] a[href='#{school_admin_classrooms_path}']", "Accueil"
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.home")
    assert_select "#departed_students tbody tr", 1
    assert_select "tr#departed_student_0" do
      assert_select "th[scope=row]", "Awa Koné"
      assert_select "td", text: /3ème 4/
      assert_select "td span", "3ème · 2025-2026"
      assert_select "td", "1"
      assert_select "td", "72 %"
    end
    assert_select "main", text: /Ailleurs/, count: 0
    assert_no_match @awa.public_id, response.body
    assert_no_match @awa.contact, response.body
  end

  test "the direction's home leads to « Anciens élèves »" do
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "a#departed-students-link[href='#{school_admin_departed_students_path}']", "Anciens élèves"
  end

  test "a name is searched in the list frame; no match and no former student have their empty state" do
    create_student(classroom: @last_year, first_name: "Yao", last_name: "Brou")
    sign_in_as @admin

    get school_admin_departed_students_path(q: "kone"), headers: { "Turbo-Frame" => "departed_students_list" }
    assert_select "turbo-frame#departed_students_list tbody tr", 1
    assert_select "turbo-frame#departed_students_list th[scope=row]", "Awa Koné"

    get school_admin_departed_students_path(q: "personne")
    assert_select "turbo-frame#departed_students_list", text: /Aucun ancien élève ne correspond/

    Orm::ClassroomStudent.delete_all
    get school_admin_departed_students_path
    assert_select "turbo-frame#departed_students_list", text: /Aucun ancien élève/
  end

  # Characterization (chantier ecrans-direction-lents): the page keeps its rows, their order, its count and its « — ».
  test "the most recent departures first, then by name; the count; a student without results reads « — »" do
    older = create_classroom(school: @school, name: "4ème 1", level: create_level(name: "4ème"), status: "archived", school_year: "2024-2025")
    create_student(classroom: older, first_name: "Aya", last_name: "Bamba")
    create_student(classroom: @last_year, first_name: "Zoé", last_name: "Yao")
    sign_in_as @admin

    get school_admin_departed_students_path

    assert_select "#departed_students p[aria-live=polite]", "3 anciens élèves"
    assert_equal [ "Awa Koné", "Zoé Yao", "Aya Bamba" ], css_select("#departed_students tbody th[scope=row]").map(&:text)
    assert_select "tr#departed_student_2" do
      assert_select "td span", "4ème · 2024-2025"
      assert_select "td", "0"
      assert_select "td span[aria-hidden=true]", "—"
    end
  end

  test "a teacher, a student and the team are refused" do
    [ create_teacher(school: @school), @awa, create_team_member ].each do |user|
      sign_in_as user
      get school_admin_departed_students_path
      assert_response :forbidden
      sign_out
    end
  end
end
