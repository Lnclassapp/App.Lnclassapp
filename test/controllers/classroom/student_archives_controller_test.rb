require "test_helper"

# Lot R of fonctions-espace-eleve (ADR-0036, memo Q19): no automatic anonymization; a student who left his classroom signs
# in and reads his archive, his classrooms and his finished exercises, from his account.
class Classroom::StudentArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @classroom = create_classroom(school: @school, name: "3ème 4", level: create_level(name: "3ème"), status: "archived",
                                  school_year: "2025-2026")
    @student = create_student(classroom: @classroom)
    course = create_course(material: create_material(name: "Mathématiques"))
    @exercise = create_exercise(essential: create_essential(course:), title: "Fractions")
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 75,
                            completed_at: Time.zone.local(2026, 3, 12, 10))
  end

  test "a student without an active classroom signs in, lands on the exit screen and opens his archive" do
    sign_in_as @student
    follow_redirect!
    assert_equal pending_account_path, path
    assert_select "#pending_account" do
      assert_select "h1", text: "Tu n'as plus de classe active"
      assert_select "a[href='#{new_join_code_path}']", text: "Rejoindre une classe"
      assert_select "a[href='#{student_archive_path}']", text: "Voir mon historique"
    end

    get student_archive_path

    assert_response :success
    assert_select "title", /Mon historique/
    assert_select "h1", "Mon historique"
    assert_select "#student_archive_classrooms li", 1 do
      assert_select "p", "3ème 4"
      assert_select "p", "3ème · Lycée Moderne de Bouaké"
      assert_select "span", "2025-2026"
    end
    assert_select "#student_archive_results li", 1 do
      assert_select "p", "Fractions"
      assert_select "span", "12 mars 2026"
      assert_select "span", "15/20"
    end
    assert_select "#student_archive_results a", 0
  end

  test "a student who never joined a classroom keeps the first exit screen, and an empty archive says what to expect" do
    sign_in_as create_student

    get pending_account_path
    assert_select "h1", text: "Tu n'as pas encore de classe"
    assert_select "a[href='#{student_archive_path}']", 0

    get student_archive_path
    assert_response :success
    assert_select "#student_archive_classrooms", text: /Aucune classe pour l'instant/
    assert_select "#student_archive_results", text: /Aucun exercice terminé/
  end

  test "a list shows 3 lines, then « Voir plus »" do
    4.times { create_exercise_session(student: @student, exercise: @exercise, status: "completed") }
    sign_in_as @student

    get student_archive_path

    assert_select "#student_archive_results li", 5
    assert_select "#student_archive_results li:not([hidden])", 3
    assert_select "#student_archive_results [data-controller=reveal] button[data-action='reveal#more']"
  end

  test "a student with an active classroom reads it too; a teacher, a school management and the team are refused" do
    sign_in_as create_student(classroom: create_classroom)
    get student_archive_path
    assert_response :success
    sign_out

    [ create_teacher, create_school_admin, create_team_member ].each do |user|
      sign_in_as user
      get student_archive_path
      assert_response :forbidden
      sign_out
    end
  end
end
