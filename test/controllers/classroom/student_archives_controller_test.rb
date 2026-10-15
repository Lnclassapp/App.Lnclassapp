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

  # IL-14 (ADR-0085 §4.3): the home of a student without a classroom carries the archive, as the exit screen did.
  test "a student without an active classroom signs in, lands on his home and opens his archive" do
    sign_in_as @student
    follow_redirect!
    assert_equal student_home_path, path
    assert_select "#student_home_no_classroom" do
      assert_select "a[href='#{new_student_classroom_choice_path}']", text: "Choisir ma classe"
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
    assert_select "#student_archive_summary", text: /1\s+exercice terminé/
    assert_select "#student_archive_results li", 1 do
      assert_select "p", "Fractions"
      assert_select "p", "Mathématiques · 12 mars"
      assert_select "[data-grade]", text: /15\/20/
    end
    assert_select "#student_archive_results a", 0
  end

  # historique-eleve (UDR-0090 §3.2, CA-3): a heading per month, most recent first; each row with its subject illustration.
  test "the finished exercises are grouped by month, most recent first, each with the illustration of its subject" do
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 70,
                            completed_at: Time.zone.local(2026, 10, 14, 9))
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 60,
                            completed_at: Time.zone.local(2026, 9, 28, 9))
    sign_in_as @student

    get student_archive_path

    assert_select "#student_archive_summary", text: /3\s+exercices terminés/
    assert_equal [ "Octobre 2026", "Septembre 2026", "Mars 2026" ],
                 css_select("#student_archive_results section h3").map { it.text.strip }
    assert_select "#student_archive_results section", 3 do |sections|
      assert_select sections.first, "li", 1
    end
    assert_select "#student_archive_results li img[alt='']", 3
  end

  # CA-4 and CA-5: green from 14/20 (70 %), at the ink below; never red; no row is a link (UDR-0013).
  test "a grade is green from 14/20, at the ink below, never red, read out « sur 20 », and no row is a link" do
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 70,
                            completed_at: Time.zone.local(2026, 3, 14, 9))
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 60,
                            completed_at: Time.zone.local(2026, 3, 13, 9))
    sign_in_as @student

    get student_archive_path

    assert_select "#student_archive_results [data-grade].bg-success-soft", text: /14\/20/
    assert_select "#student_archive_results [data-grade].bg-success-soft", text: /15\/20/
    assert_select "#student_archive_results [data-grade].bg-mist", text: /12\/20/
    assert_select "#student_archive_results [data-grade] .sr-only", text: "12 sur 20"
    assert_select "#student_archive_results [class*=error], #student_archive_results [class*=danger]", 0
    assert_select "#student_archive_results a", 0
  end

  test "a student who never joined a classroom keeps the first exit screen, and an empty archive says what to expect" do
    sign_in_as create_student

    get pending_account_path
    assert_select "h1", text: "Tu n'as pas encore de classe"
    # The page itself; the avatar menu of the header always offers « Mon historique » (UDR-0084 §3.2).
    assert_select "main a[href='#{student_archive_path}']", 0

    get student_archive_path
    assert_response :success
    assert_select "#student_archive_summary", text: /Aucun exercice terminé pour l'instant/
    assert_select "#student_archive_classrooms", text: /Aucune classe pour l'instant/
    assert_select "#student_archive_results", text: /Aucun exercice terminé/
  end

  test "a list shows 3 lines, then « Voir plus »" do
    4.times { create_exercise_session(student: @student, exercise: @exercise, status: "completed") }
    sign_in_as @student

    get student_archive_path

    assert_select "#student_archive_results li", 5
    assert_select "#student_archive_results li:not([hidden])", 3
    assert_select "#student_archive_results [data-controller=reveal][data-reveal-step-value='10'] button[data-action='reveal#more']"
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
