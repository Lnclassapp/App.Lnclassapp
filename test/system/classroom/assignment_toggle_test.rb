require "application_system_test_case"

# CL-12, CL-16, CL-17, CL-20, AS-18, AS-19 (UDR-0028, UDR-0029): from the sheet page of their classroom, the teacher
# assigns an exercise, then another, withdraws one and assigns it again — toggles and toasts change in place, without a
# page reload, and the reassignment adds a new row instead of raising the old uniqueness error. ADR-0072: the course and
# its sheets are no longer assigned; the course page of the classroom has no toggle. UDR-0062 §3.4: the first « Assigner »
# of a teacher without session days asks « Quels jours voyez-vous la <classe> ? », with « Plus tard »; the due date is the
# next session day (clock on Monday 5 October 2026).
class Classroom::AssignmentToggleTest < ApplicationSystemTestCase
  # The teacher home belongs to Lot D3: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/drenas_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Classroom::TeacherHomesController")
    Classroom.const_set(:TeacherHomesController, Class.new(AuthenticatedController) { def show = render(html: "home", layout: true) })
  end

  DAYS_MODAL = "turbo-frame#modal dialog[open]".freeze

  setup do
    travel_to Time.zone.local(2026, 10, 5, 10)
    @course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"))
    # UDR-0013, amendement du 2026-10-01 : un contenu ne s'assigne qu'à une classe de son niveau.
    @classroom = create_classroom(name: "6ème 1", level: @course.level)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @meiose = create_essential(course: @course, name: "Méiose")
    create_essential(course: @course, name: "Mitose")
    @phases = create_exercise(essential: @meiose, title: "Les phases")
    @bilan = create_exercise(essential: @meiose, title: "Le bilan")
  end

  def toggle(type, key) = "#assignment_#{@classroom.public_id}_#{type}_#{key}"
  def sheet_path = classroom_essential_path(@classroom.public_id, @course.slug, @meiose.slug)

  def sign_in_teacher
    sign_in_as @teacher
    assert_current_path teacher_home_path
  end

  test "the course page of the classroom offers no toggle: its sheets lead to the sheet in the classroom" do
    sign_in_teacher
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

  # PRD, chemin nominal A ; plan, Lot C « Done quand ».
  test "without days, « Assigner » asks the days; Monday and Thursday give « Pour jeu. 8 oct. », then one click is enough" do
    sign_in_teacher
    visit sheet_path
    assert_selector "#classroom_essential_exercises li", count: 2

    assert_no_page_reload do
      within(toggle("Exercise", @phases.public_id)) { click_on "Assigner" }
      within DAYS_MODAL do
        assert_selector "h2", text: "Quels jours voyez-vous la 6ème 1 ?"
        assert_text "Les phases sera à rendre pour la séance suivante."
        assert_equal [ "Lun.", "Mar.", "Mer.", "Jeu.", "Ven.", "Sam." ], all("fieldset label span[aria-hidden]").map(&:text)
        find("label", text: "Lun.").click
        find("label", text: "Jeu.").click
        click_on "Assigner"
      end
      assert_toast "Les phases ajouté à 6ème 1, à rendre jeudi 8 oct."
      assert_no_selector DAYS_MODAL
      within(toggle("Exercise", @phases.public_id)) do
        assert_text "Assigné"
        assert_text "Pour jeu. 8 oct."
      end

      # Les autres « Assigner » de la page n'ouvrent plus la modale (page rafraîchie par morphing).
      within(toggle("Exercise", @bilan.public_id)) { click_on "Assigner" }
      assert_toast "Le bilan ajouté à 6ème 1, à rendre jeudi 8 oct."
      assert_no_selector DAYS_MODAL

      within(toggle("Exercise", @phases.public_id)) { click_on "Retirer" }
      assert_toast "Les phases retiré de 6ème 1."
      within(toggle("Exercise", @phases.public_id)) do
        assert_no_text "Assigné"
        click_on "Assigner"
      end
      within(toggle("Exercise", @phases.public_id)) { assert_button "Retirer" }
    end

    assert_equal [ 1, 4 ], Orm::ClassroomSessionDay.where(teacher_id: @teacher.id).order(:weekday).pluck(:weekday)
    rows = Orm::ClassroomAssignment.where(assignable_type: "Exercise", assignable_id: @phases.id).order(:id)
    assert_equal [ "archived", "active" ], rows.pluck(:status)
    assert_equal [ Date.new(2026, 10, 8) ], Orm::ClassroomAssignment.distinct.pluck(:due_on)
    assert_equal [ @teacher.id ], Orm::ClassroomAssignment.distinct.pluck(:assigned_by_id)
  end

  test "« Plus tard » assigns without due date, and the next « Assigner » asks again" do
    sign_in_teacher
    visit sheet_path

    assert_no_page_reload do
      within(toggle("Exercise", @phases.public_id)) { click_on "Assigner" }
      within(DAYS_MODAL) { click_on "Plus tard" }
      assert_toast "Les phases ajouté à 6ème 1."
      assert_no_selector DAYS_MODAL
      within(toggle("Exercise", @phases.public_id)) do
        assert_text "Assigné"
        assert_no_text "Pour "
      end

      within(toggle("Exercise", @bilan.public_id)) { click_on "Assigner" }
      assert_selector DAYS_MODAL, text: "Le bilan sera à rendre pour la séance suivante."
    end
    assert_nil Orm::ClassroomAssignment.sole.due_on
    assert_equal 0, Orm::ClassroomSessionDay.count
  end

  test "« Assigner » without any day keeps the modal open with its error, and writes nothing" do
    sign_in_teacher
    visit sheet_path

    within(toggle("Exercise", @phases.public_id)) { click_on "Assigner" }
    within(DAYS_MODAL) { click_on "Assigner" }

    within DAYS_MODAL do
      assert_selector "fieldset[aria-invalid=true]"
      assert_text "Cochez au moins un jour, ou choisissez « Plus tard »."
    end
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "a team member assigns in one click, without modal nor due date" do
    sign_in_as create_team_member
    visit sheet_path

    within(toggle("Exercise", @phases.public_id)) { click_on "Assigner" }
    assert_toast "Les phases ajouté à 6ème 1."
    assert_no_selector DAYS_MODAL
    assert_nil Orm::ClassroomAssignment.sole.due_on
  end

  test "on a phone, the days modal fits the screen and the toggle works in place" do
    sign_in_teacher
    with_mobile_viewport do
      visit sheet_path

      assert_no_page_reload do
        within(toggle("Exercise", @phases.public_id)) { click_on "Assigner" }
        within DAYS_MODAL do
          find("label", text: "Mer.").click
          click_on "Assigner"
        end
        assert_toast "Les phases ajouté à 6ème 1, à rendre mercredi 7 oct."
      end
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
