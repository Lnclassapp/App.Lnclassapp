require "application_system_test_case"

# Chantier entree-et-accueil-eleve-allegees, Lot D, PRD CA-13 (UDR accueil-eleve-qr-fenetre-inviter §3.2) : la fenêtre « Ton premier
# exercice » s'ouvre à l'arrivée de l'élève ; fermée, elle revient sur l'écran suivant ; jamais en mode exercice.
class StudentFirstExercisePromptTest < ApplicationSystemTestCase
  MODAL = "#student_first_exercise_modal".freeze

  setup do
    @classroom = create_classroom(name: "3e B", school: create_school(name: "Collège Moderne"), level: create_level(name: "3ème"))
    course = create_course(level: @classroom.level, material: create_material(name: "Mathématiques"), name: "Les angles")
    @exercise = create_exercise(course:, lesson_wide: true, title: "Mesurer un angle")
    @student = create_student(classroom: @classroom, joined_via: "standard")
    sign_in_as @student
  end

  test "CA-13: the window opens on the home, closes, comes back on the next screen, never on an exercise" do
    visit student_home_path

    assert_selector "dialog#{MODAL}[open]", text: "Mesurer un angle"
    assert_selector "#student_first_exercise_start:focus"
    find("#student_first_exercise_later").click
    assert_no_selector "dialog#{MODAL}[open]"

    first("#student_subjects a").click
    assert_current_path %r{\A/courses}
    assert_selector "dialog#{MODAL}[open]", text: "Mesurer un angle"

    find("#student_first_exercise_start").click
    assert_current_path %r{\A/sessions/}
    assert_no_selector MODAL
  end

  test "CA-13: Escape closes the window, and a copy handed in ends it for good" do
    visit student_home_path
    assert_selector "dialog#{MODAL}[open]"
    page.send_keys :escape
    assert_no_selector "dialog#{MODAL}[open]"

    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 0)
    visit courses_path
    assert_no_selector MODAL
    visit student_home_path
    assert_no_selector "turbo-frame#student_first_exercise_prompt"
  end
end
