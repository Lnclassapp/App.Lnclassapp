require "application_system_test_case"

# CL-12, CL-16, CL-17, CL-20, AS-18, AS-19 (UDR-0028, UDR-0029): from the sheet page of their classroom, the teacher
# assigns an exercise, then another, withdraws one and assigns it again — toggles and toasts change in place, without a
# page reload, and the reassignment adds a new row instead of raising the old uniqueness error. ADR-0072: the course and
# its sheets are no longer assigned; the course page of the classroom has no toggle.
class Classroom::AssignmentToggleTest < ApplicationSystemTestCase
  # The teacher home belongs to Lot D3: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/drenas_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Classroom::TeacherHomesController")
    Classroom.const_set(:TeacherHomesController, Class.new(AuthenticatedController) { def show = render(html: "home", layout: true) })
  end

  setup do
    @course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"))
    # UDR-0013, amendement du 2026-10-01 : un contenu ne s'assigne qu'à une classe de son niveau.
    @classroom = create_classroom(name: "6ème 1", level: @course.level)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @meiose = create_essential(course: @course, name: "Méiose")
    create_essential(course: @course, name: "Mitose")
    @phases = create_exercise(essential: @meiose, title: "Les phases")
    @bilan = create_exercise(essential: @meiose, title: "Le bilan")
    sign_in_as @teacher
    assert_current_path teacher_home_path
  end

  def toggle(type, key) = "#assignment_#{@classroom.public_id}_#{type}_#{key}"

  test "the course page of the classroom offers no toggle: its sheets lead to the sheet in the classroom" do
    visit classroom_course_path(@classroom.public_id, @course.slug)
    assert_selector "h1", text: "Génétique"
    assert_selector "#classroom_course_essentials li", count: 2
    assert_no_button "Assigner"
    assert_no_selector "[id^='assignment_']"

    click_on "Méiose"
    assert_selector "h1", text: "Méiose"
    assert_no_selector "[role=group]"
    assert_no_selector toggle("Essential", @meiose.slug)
  end

  test "assign an exercise, then another, withdraw the first and assign it again, without a page reload" do
    visit classroom_essential_path(@classroom.public_id, @course.slug, @meiose.slug)
    assert_selector "h1", text: "Méiose"
    assert_selector "#classroom_essential_exercises li", count: 2

    assert_no_page_reload do
      within(toggle("Exercise", @phases.public_id)) { click_on "Assigner" }
      assert_toast "Les phases ajouté à 6ème 1."
      within(toggle("Exercise", @phases.public_id)) { assert_text "Assigné" }

      within(toggle("Exercise", @bilan.public_id)) { click_on "Assigner" }
      assert_toast "Le bilan ajouté à 6ème 1."

      within(toggle("Exercise", @phases.public_id)) { click_on "Retirer" }
      assert_toast "Les phases retiré de 6ème 1."
      within(toggle("Exercise", @phases.public_id)) do
        assert_no_text "Assigné"
        click_on "Assigner"
      end
      within(toggle("Exercise", @phases.public_id)) { assert_button "Retirer" }
    end

    rows = Orm::ClassroomAssignment.where(assignable_type: "Exercise", assignable_id: @phases.id).order(:id)
    assert_equal [ "archived", "active" ], rows.pluck(:status)
    assert_equal [ "Exercise" ], Orm::ClassroomAssignment.distinct.pluck(:assignable_type)
    assert_equal [ @teacher.id ], Orm::ClassroomAssignment.distinct.pluck(:assigned_by_id)
  end

  test "on a phone, the toggle stays reachable and works in place" do
    with_mobile_viewport do
      visit classroom_essential_path(@classroom.public_id, @course.slug, @meiose.slug)

      assert_no_page_reload do
        within(toggle("Exercise", @phases.public_id)) { click_on "Assigner" }
        assert_toast "Les phases ajouté à 6ème 1."
      end
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
