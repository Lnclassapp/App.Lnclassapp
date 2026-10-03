require "application_system_test_case"

# CA-27 (UDR-0030): from the « Assigner à mes classes » page of a published course, the teacher assigns it to two of
# their classrooms — each toggle and toast changes in place, without a page reload. The old footer was never rendered.
class Classroom::CourseAssignmentsTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"))
    # UDR-0013, amendement du 2026-10-01 : un contenu ne s'assigne qu'à une classe de son niveau.
    @first = create_classroom(name: "Tle D 1", level: @course.level)
    @second = create_classroom(name: "Tle D 2", level: @course.level)
    @teacher = create_teacher(classrooms: [ @first, @second ])
    sign_in_as @teacher
    assert_current_path teacher_home_path
  end

  def toggle(classroom) = "#assignment_#{classroom.public_id}_Course_#{@course.slug}"

  test "assign the course to two classrooms, without a page reload" do
    visit course_assignments_path(@course.slug)
    assert_selector "h1", text: "Génétique"
    assert_selector "#course_assignment_classrooms li", count: 2

    assert_no_page_reload do
      within(toggle(@first)) { click_on "Assigner" }
      assert_toast "Génétique ajouté à Tle D 1."
      within(toggle(@first)) { assert_text "Assigné" }

      within(toggle(@second)) { click_on "Assigner" }
      assert_toast "Génétique ajouté à Tle D 2."
      within(toggle(@second)) { assert_button "Retirer" }
    end

    assert_equal [ @first.id, @second.id ].sort,
                 Orm::ClassroomAssignment.where(assignable_type: "Course", assignable_id: @course.id, status: "active")
                                         .pluck(:classroom_id).sort
  end

  test "on a phone, each toggle stays reachable and the page never scrolls sideways" do
    with_mobile_viewport do
      visit course_assignments_path(@course.slug)

      assert_no_page_reload do
        within(toggle(@second)) { click_on "Assigner" }
        assert_toast "Génétique ajouté à Tle D 2."
      end
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
