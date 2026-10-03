require "application_system_test_case"

# CL-22, CL-10 (volet élève) — UDR-0011. L'élève ouvre « Ma classe » depuis la navigation : il voit le code de sa classe
# en majuscules et ses cours assignés, puis ouvre l'un d'eux, sans rechargement de page.
class Classroom::StudentClassroomTest < ApplicationSystemTestCase
  setup do
    @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"), series: create_series(name: "D"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    # UDR-0013, amendement du 2026-10-01 : le cours assigné est du niveau et de la série de la classe.
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            level: @classroom.level, series: @classroom.series)
    create_essential(course: @course)
    create_assignment(classroom: @classroom, assignable: @course)
    create_assignment(classroom: @classroom, assignable: create_course(name: "Écologie"), status: "archived")
  end

  def tl(key, **) = I18n.t("classroom.student_classrooms.#{key}", **)

  test "the student sees their classroom code and assigned courses, then opens a course" do
    sign_in_as @student

    assert_no_page_reload do
      click_on I18n.t("shared.navigation.classroom"), match: :first
      assert_current_path student_classroom_path
    end
    within "#student_classroom_header" do
      assert_selector "h2", text: "Tle D 1"
      assert_selector "#student_classroom_join_code", exact_text: "KFM37"
    end
    assert_selector "#student_classroom_courses li", count: 1
    assert_no_text "Écologie"

    assert_no_page_reload do
      click_on "Génétique et évolution"
      assert_current_path course_path(@course.slug)
      assert_selector "h1", text: "Génétique et évolution"
    end
  end
end
