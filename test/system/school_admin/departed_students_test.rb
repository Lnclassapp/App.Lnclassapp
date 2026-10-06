require "application_system_test_case"

# Lot R of fonctions-espace-eleve (ADR-0036, memo Q19): from its home, the direction opens « Anciens élèves »
# and finds, by typing a name, a former student and the results he obtained in its school, without a page reload.
class SchoolAdmin::DepartedStudentsTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
    classroom = create_classroom(school: @school, name: "3ème 4", status: "archived", school_year: "2025-2026")
    teacher = create_teacher(school: @school)
    { "Awa Koné" => 80, "Yao Brou" => 40 }.each do |name, score|
      first_name, last_name = name.split
      student = create_student(classroom:, first_name:, last_name:)
      exercise = create_exercise
      assignment = create_assignment(classroom:, assignable: exercise, by: teacher)
      create_exercise_session(student:, exercise:, status: "completed", score_percent: score, classroom_assignment_id: assignment.id)
    end
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end

  def t(key, **) = I18n.t("school_admin.departed_students.index.#{key}", **)

  test "at 390 px, the direction opens « Anciens élèves » and searches a former student by name" do
    with_mobile_viewport do
      sign_in_as @admin
      assert_selector "main#main", wait: SIGN_IN_WAIT

      assert_no_page_reload do
        click_on I18n.t("school_admin.classrooms.school_card.links.departed")
        assert_current_path school_admin_departed_students_path
        assert_selector "h1", text: t("title")
      end
      assert_selector "#departed_students tbody tr", count: 2
      assert_no_horizontal_scroll

      assert_no_page_reload do
        fill_in t("search.label"), with: "kone"
        assert_selector "#departed_students tbody tr", count: 1
      end
      within("#departed_student_0") do
        assert_selector "th", text: "Awa Koné"
        assert_text "80 %"
      end
    end
  end
end
