require "application_system_test_case"

# Chantier parcours-matiere-exercice — UDR parcours-matiere-exercice §3 : de la grille de l'accueil à la feuille d'un exercice
# en deux clics (matière, puis « Commencer l'exercice »), à 390 px et sur ordinateur.
class Catalog::NextExercisePathTest < ApplicationSystemTestCase
  setup do
    @level = create_level(name: "3ème")
    @maths = create_material(name: "Mathématiques")
    @course = create_course(level: @level, material: @maths, name: "Les fractions", subtitle: "Leçon 1")
    @exercise = create_lesson_wide_exercise(course: @course, title: "Additionner des fractions")
    @student = create_student(classroom: create_classroom(level: @level))
    sign_in_as @student
  end

  def start_label = I18n.t("catalog.courses.next_exercise.start")

  test "CA-1, CA-8 on a phone: grid, subject, « Commencer l'exercice », the sheet of the session" do
    with_mobile_viewport do
      visit student_home_path
      find("#subject_mathematiques").click
      within("#material_next_exercise") do
        assert_text "Additionner des fractions"
        click_on start_label
      end

      assert_current_path %r{\A/sessions/[^/]+\z}
      assert_selector "#copy-form"
    end
  end

  test "CA-1, CA-8 on desktop: the card sits under the subject pills, and opens the sheet" do
    visit student_home_path
    find("#subject_mathematiques").click
    within("#lesson_material_next_exercise") { click_on start_label }

    assert_current_path %r{\A/sessions/[^/]+\z}
    assert_selector "#copy-form"
  end

  test "CA-5: from a lesson, the card starts the exercise too" do
    visit course_path(@course.slug)
    within("#lesson_next_exercise") { click_on start_label }

    assert_selector "#copy-form"
  end
end
