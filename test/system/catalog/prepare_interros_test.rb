require "application_system_test_case"

# refonte-page-lecon (CA-06, CA-07), UDR-0139 §3.4 : the teacher opens the lesson, sees its exercises grouped, clicks « Assigner »
# for their classroom and the row turns « Assignée » without a page reload (the Turbo Stream replaces the toggle).
class Catalog::PrepareInterrosTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "Le théorème", position: 1)
    @exercise = create_exercise(essential: @notion, title: "Calculer une longueur")
    @wide = create_lesson_wide_exercise(course: @course, title: "Bilan de la leçon")
    @classroom = create_classroom(name: "3ème 1", level: @course.level, series: @course.series)
    @teacher = create_teacher(classrooms: [ @classroom ])
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ],
                                                                at: Time.current)
  end

  def toggle(key) = I18n.t("classroom.assignments.toggle.#{key}")

  test "the teacher assigns an exercise to their classroom without reloading the page" do
    sign_in_as @teacher
    visit course_path(@course.slug)
    page.execute_script("window.lnclassNotReloaded = true")

    within "#prepare-interros" do
      assert_selector "h3", text: "Le théorème"
      assert_selector "#toute-la-lecon h3"
      within "#exercise-#{@exercise.public_id}" do
        assert_text "3ème 1"
        click_button toggle(:assign)
        assert_text toggle(:assigned)
        assert_no_button toggle(:assign)
      end
      assert_selector "#exercise-#{@wide.public_id}", text: toggle(:assign)
    end

    assert page.evaluate_script("window.lnclassNotReloaded")
    assert_equal 1, Orm::ClassroomAssignment.where(assignable_id: @exercise.id, classroom_id: @classroom.id, status: "active").count
  end

  # Lot C : un exercice de toute la leçon s'ouvre depuis « Prépare interros » : feuille, copie, résultat.
  test "a student opens the whole-lesson exercise from the lesson page, hands in a copy and reads the result" do
    sign_in_as create_student_for(@course)

    visit course_path(@course.slug)
    within("#toute-la-lecon") { click_on "Bilan de la leçon" }
    assert_current_path exercise_path(@wide.public_id)
    assert_selector "#exercise-sheet"
    click_on I18n.t("assessment.exercises.show.start")

    hand_in_copy(rights: 1, questions: 2)
    assert_selector "#session_grade"
  end
end
