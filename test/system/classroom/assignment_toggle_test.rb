require "application_system_test_case"

# CL-11, CL-16, CL-17, CL-20, AS-18, AS-19 (UDR-0028): from the course page of their classroom, the teacher assigns the
# course, then a sheet, withdraws the sheet and assigns it again — toggles and toasts change in place, without a page
# reload, and the reassignment adds a new row instead of raising the old uniqueness error.
class Classroom::AssignmentToggleTest < ApplicationSystemTestCase
  # The teacher home belongs to Lot D3: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/drenas_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Classroom::TeacherHomesController")
    Classroom.const_set(:TeacherHomesController, Class.new(AuthenticatedController) { def show = render(html: "home", layout: true) })
  end

  setup do
    @classroom = create_classroom(name: "6ème 1")
    @teacher = create_teacher(classrooms: [ @classroom ])
    @course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"))
    @meiose = create_essential(course: @course, name: "Méiose")
    create_essential(course: @course, name: "Mitose")
    sign_in_as @teacher
    assert_current_path teacher_home_path
  end

  def toggle(type, key) = "#assignment_#{@classroom.public_id}_#{type}_#{key}"

  test "assign the course, then a sheet, withdraw it and assign it again, without a page reload" do
    visit classroom_course_path(@classroom.public_id, @course.slug)
    assert_selector "h1", text: "Génétique"
    assert_selector "#classroom_course_essentials li", count: 2

    assert_no_page_reload do
      within(toggle("Course", @course.slug)) { click_on "Assigner" }
      assert_toast "Génétique ajouté à 6ème 1."
      within(toggle("Course", @course.slug)) { assert_text "Assigné" }

      within(toggle("Essential", @meiose.slug)) { click_on "Assigner" }
      assert_toast "Méiose ajouté à 6ème 1."
      within(toggle("Essential", @meiose.slug)) do
        assert_text "Assigné"
        click_on "Retirer"
      end
      assert_toast "Méiose retiré de 6ème 1."
      within(toggle("Essential", @meiose.slug)) do
        assert_no_text "Assigné"
        click_on "Assigner"
      end
      within(toggle("Essential", @meiose.slug)) { assert_button "Retirer" }
    end

    rows = Orm::ClassroomAssignment.where(assignable_type: "Essential", assignable_id: @meiose.id).order(:id)
    assert_equal [ "archived", "active" ], rows.pluck(:status)
    assert_equal [ @teacher.id ], Orm::ClassroomAssignment.distinct.pluck(:assigned_by_id)
  end

  test "on a phone, the toggle stays reachable and works in place" do
    with_mobile_viewport do
      visit classroom_course_path(@classroom.public_id, @course.slug)

      assert_no_page_reload do
        within(toggle("Essential", @meiose.slug)) { click_on "Assigner" }
        assert_toast "Méiose ajouté à 6ème 1."
      end
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
