require "application_system_test_case"

# prepare-interros-cahier, Lot D (CA-8), UDR feuilles-prepare-interros-et-devoirs §3 (Vue enseignant) : l'enseignant lit la feuille sans champ
# ni « Vérifier ma réponse », clique « Assigner à <classe> » et lit « ✓ Assigné à <classe> » sans rechargement ; l'équipe lit la feuille sans « Assigner ».
class Catalog::PrepareInterrosTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "Le théorème", position: 1)
    @exercise = create_exercise(essential: @notion, title: "Calculer une longueur")
    @wide = create_lesson_wide_exercise(course: @course, title: "Bilan de la leçon")
    @classroom = create_classroom(name: "3e 1", level: @course.level, series: @course.series)
    @teacher = create_teacher(classrooms: [ @classroom ])
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ],
                                                                at: Time.current)
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"

  test "the teacher reads the sheet without field nor check, and assigns an exercise to their classroom without reloading the page" do
    sign_in_as @teacher
    visit course_path(@course.slug)
    page.execute_script("window.lnclassNotReloaded = true")

    within "#prepare-interros" do
      assert_selector ".ps-title", text: "LE THÉORÈME"
      within frame(@exercise) do
        assert_no_selector "input, textarea, [role=radio], [role=radiogroup]"
        assert_no_button "Vérifier ma réponse"
        assert_no_button "Indice"
        assert_button "Assigner à 3e 1"
        click_button "Assigner à 3e 1"
        assert_selector "[role=status]", text: "✓ Assigné à 3e 1"
        assert_no_button "Assigner à 3e 1"
      end
      within("#toute-la-lecon") { assert_button "Assigner à 3e 1" }
    end

    assert page.evaluate_script("window.lnclassNotReloaded")
    assert_equal 1, Orm::ClassroomAssignment.where(assignable_id: @exercise.id, classroom_id: @classroom.id, status: "active").count
  end

  test "the teacher withdraws an assigned exercise from the sheet, and the label comes back" do
    sign_in_as @teacher
    visit course_path(@course.slug)

    within frame(@exercise) do
      click_button "Assigner à 3e 1"
      assert_selector "[role=status]", text: "✓ Assigné à 3e 1"
      click_button "Retirer"
      assert_button "Assigner à 3e 1"
      assert_no_selector "[role=status]"
    end
  end

  test "the team reads the sheet without any « Assigner »" do
    sign_in_as create_team_member
    visit course_path(@course.slug)

    within "#prepare-interros" do
      assert_selector ".ps-title", text: "LE THÉORÈME"
      assert_selector frame(@exercise)
      assert_no_button "Assigner", exact: false
      assert_no_button "Vérifier ma réponse"
      assert_no_selector "input, textarea, [role=radio]"
    end
  end

  # Lot C : un exercice de toute la leçon se lit dans la dernière feuille, sans quitter la page.
  test "a student reads the whole-lesson exercise in the « Toute la leçon » sheet, with « Vérifier ma réponse »" do
    sign_in_as create_student_for(@course)

    visit course_path(@course.slug)
    within("#toute-la-lecon") do
      assert_selector frame(@wide)
      within(frame(@wide)) { assert_button "Vérifier ma réponse" }
    end
  end
end
