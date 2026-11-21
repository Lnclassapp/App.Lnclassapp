require "application_system_test_case"

# Chantier activation-eleve, PRD CA-10 (UDR-0174) : de l'inscription au premier exercice, en un tap
# depuis l'accueil. L'élève qui a choisi sa classe reçoit le devoir de sa classe ; l'élève seul, le programme.
class Classroom::StudentActivationTest < ApplicationSystemTestCase
  FORM = "classroom.student_registrations.form".freeze

  setup do
    @classroom = create_classroom(school: create_school(name: "Collège Moderne 1 de Tiassalé"), level: create_level(name: "3ème"), name: "3e B")
    course = create_course(level: @classroom.level, material: create_material(name: "Mathématiques"), name: "Les angles")
    @program = create_exercise(course:, lesson_wide: true, title: "Mesurer un angle")
    @homework = create_exercise(course:, lesson_wide: true, title: "Angles opposés")
  end

  test "CA-10, CA-3, CA-9: brought by the class (picked in the cascade), the home offers the assignment; one tap opens the copy" do
    create_assignment(classroom: @classroom, assignable: @homework)
    visit new_student_registration_path
    choose_school "Collège Moderne 1 de Tiassalé", search: "moderne tiassale"
    within("turbo-frame#picker_levels") { choose "3ème" }
    within("turbo-frame#picker_classrooms") { choose "3e B" }
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "0701020399"
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_current_path student_home_path
    # Choisie dans la cascade (« standard »), la classe ne donne pas la fenêtre : elle propose le programme ; le devoir est dans « À faire ».
    within "#student_first_exercise_modal" do
      assert_text I18n.t("catalog.courses.next_exercise.first")
      assert_text "Mesurer un angle"
      find("#student_first_exercise_later").click
    end
    assert_selector "#student_to_do", text: "Angles opposés"
    within("#student_to_do") { click_on "Angles opposés" }

    assert_current_path %r{\A/exercises/}
    click_on I18n.t("assessment.exercises.show.start")
    assert_current_path %r{\A/sessions/}
    student = Orm::User.find_by!(contact: "0701020399", role: "student")
    assert_current_path exercise_session_path(Orm::ExerciseSession.find_by!(student:, exercise: @homework).public_id)
  end

  test "CA-1, CA-8: alone, the home offers the first exercise of the program; one tap opens the copy" do
    student = create_student(classroom: @classroom, joined_via: "standard")
    sign_in_as student

    visit student_home_path
    within "#student_first_exercise_modal" do
      assert_text "Mesurer un angle"
      assert_text "Mathématiques · Les angles"
      click_on I18n.t("catalog.courses.next_exercise.start")
    end

    assert_current_path %r{\A/sessions/}
    assert_current_path exercise_session_path(Orm::ExerciseSession.find_by!(student:, exercise: @program).public_id)
  end
end
