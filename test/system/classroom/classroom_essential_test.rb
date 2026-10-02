require "application_system_test_case"

# CL-12, AS-20 (UDR-0029): from the essential sheet of their classroom, the teacher assigns an exercise, then withdraws
# it — the D5 toggle and toasts change in place, without a page reload. UDR-0062 §3.4: with session days, the toggle
# shows the due date; unchecking every day brings the days modal back.
class Classroom::ClassroomEssentialTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Génétique")
    # UDR-0013, amendement du 2026-10-01 : un contenu ne s'assigne qu'à une classe de son niveau.
    @classroom = create_classroom(name: "6ème 1", level: @course.level)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @essential = create_essential(course: @course, name: "Méiose")
    @phases = create_exercise(essential: @essential, title: "Les phases")
    create_exercise(essential: @essential, title: "Le brassage")
    create_exercise(essential: @essential, title: "Brouillon", status: "draft")
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 2 ],
                                                                at: Time.current)
    sign_in_as @teacher
    assert_current_path teacher_home_path
  end

  def toggle = "#assignment_#{@classroom.public_id}_Exercise_#{@phases.public_id}"

  test "assign an exercise, then withdraw it, without a page reload" do
    visit classroom_essential_path(@classroom.public_id, @course.slug, @essential.slug)
    assert_selector "h1", text: "Méiose"
    assert_selector "#classroom_essential_exercises li", count: 2
    assert_no_text "Brouillon"

    due = I18n.l(Time.zone.today.next_occurring(:tuesday), format: :due_short)
    assert_no_page_reload do
      within(toggle) { click_on "Assigner" }
      assert_toast "Les phases ajouté à 6ème 1, à rendre"
      within(toggle) do
        assert_text "Assigné"
        assert_text "Pour #{due}"
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

  # Le bouton « Modifier » est sur la page de la classe (Lot E) : la modale s'ouvre ici dans le frame, comme lui.
  test "unchecking every session day brings the days modal back on « Assigner »" do
    visit classroom_essential_path(@classroom.public_id, @course.slug, @essential.slug)

    assert_no_page_reload do
      open_in_modal edit_classroom_session_days_path(@classroom.public_id)
      within "turbo-frame#modal dialog[open]" do
        assert_text "Les dates déjà données ne changent pas."
        find("label", text: "Mar.").click
        click_on "Enregistrer"
      end
      assert_toast "Jours de séance enregistrés."
      assert_no_selector "turbo-frame#modal dialog[open]"

      # Le refresh par morphing remplace le bouton par le lien de la modale : cliquer avant, c'est assigner sans date.
      within(toggle) { find_link("Assigner").click }
      assert_selector "turbo-frame#modal dialog[open]", text: "Quels jours voyez-vous la 6ème 1 ?"
    end
    assert_equal 0, Orm::ClassroomSessionDay.count
    assert_equal 0, Orm::ClassroomAssignment.count
  end
end
