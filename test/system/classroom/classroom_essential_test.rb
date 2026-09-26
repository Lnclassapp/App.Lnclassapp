require "application_system_test_case"

# CL-12, AS-20 (UDR-0029): from the essential sheet of their classroom, the teacher assigns an exercise, then withdraws
# it — the D5 toggle and toasts change in place, without a page reload.
class Classroom::ClassroomEssentialTest < ApplicationSystemTestCase
  setup do
    @classroom = create_classroom(name: "6ème 1")
    @teacher = create_teacher(classrooms: [ @classroom ])
    @course = create_course(name: "Génétique")
    @essential = create_essential(course: @course, name: "Méiose")
    @phases = create_exercise(essential: @essential, title: "Les phases")
    create_exercise(essential: @essential, title: "Le brassage")
    create_exercise(essential: @essential, title: "Brouillon", status: "draft")
    sign_in_as @teacher
    assert_current_path teacher_home_path
  end

  def toggle = "#assignment_#{@classroom.public_id}_Exercise_#{@phases.public_id}"

  test "assign an exercise, then withdraw it, without a page reload" do
    visit classroom_essential_path(@classroom.public_id, @course.slug, @essential.slug)
    assert_selector "h1", text: "Méiose"
    assert_selector "#classroom_essential_exercises li", count: 2
    assert_no_text "Brouillon"

    assert_no_page_reload do
      within(toggle) { click_on "Assigner" }
      assert_toast "Les phases ajouté à 6ème 1."
      within(toggle) do
        assert_text "Assigné"
        click_on "Retirer"
      end
      assert_toast "Les phases retiré de 6ème 1."
      within(toggle) do
        assert_no_text "Assigné"
        assert_button "Assigner"
      end
    end

    row = Orm::ClassroomAssignment.find_by!(assignable_type: "Exercise", assignable_id: @phases.id)
    assert_equal [ "archived", @teacher.id ], [ row.status, row.assigned_by_id ]
  end
end
