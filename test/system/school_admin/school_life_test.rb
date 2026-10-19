require "application_system_test_case"

# ED-33, ED-60 (ADR-0092 §4.3, UDR-0092 §3.5, UDR-0094), on a 390 px phone, without horizontal scroll: a secretary reads
# « Établissement » without « + » nor « − » and with the note of her position; from her home she looks for « kouas »,
# opens the result and lands on the classroom filtered on the student's name. One scenario, one browser (ADR-0069 §9):
# the refusals and their 403 live in the controller tests.
class SchoolAdmin::SchoolLifeTest < ApplicationSystemTestCase
  setup do
    school = create_school(name: "Lycée Moderne de Bouaké", school_type: "public")
    @sixth = create_classroom(school:, level: create_level(name: "6ème", position: 1, cycle: "first"), name: "6ème 3")
    create_student(classroom: @sixth, first_name: "Aya", last_name: "Kouassi")
    create_student(classroom: @sixth, first_name: "Marc", last_name: "Aka")
    @secretary = create_school_admin(school:, first_name: "Awa", last_name: "Koné", position: "secretary")
  end

  def no_horizontal_scroll? = evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")

  test "ED-33, ED-60: the secretary has no structure gesture, then finds a student from her home" do
    with_mobile_viewport do
      sign_in_as @secretary

      visit school_admin_school_path
      assert_selector "#rank_note", text: I18n.t("shared.staff_positions.secretary")
      assert_selector "#school_level_classrooms"
      assert_no_selector "#school_level_classrooms form"
      assert no_horizontal_scroll?, "« Établissement » défile en largeur à 390 px"

      visit school_admin_classrooms_path
      within("#direction_home_student_search") do
        fill_in I18n.t("school_admin.student_searches.form.label"), with: "kouas"
        click_on I18n.t("school_admin.student_searches.form.submit")
      end
      assert_selector "#student_search_list li", count: 1
      assert no_horizontal_scroll?, "les résultats défilent en largeur à 390 px"

      find("#student_result_0 a").click
      assert_current_path school_admin_classroom_path(@sixth.public_id, q: "Aya Kouassi")
      assert_text "Aya Kouassi"
      assert_no_text "Marc Aka"
    end
  end
end
