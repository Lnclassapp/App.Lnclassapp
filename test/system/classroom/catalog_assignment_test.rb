require "application_system_test_case"

# RE-21, RE-23 (UDR-0069 §3.8) : depuis une fiche du catalogue, l'enseignant assigne un exercice à l'une de ses classes du
# niveau et de la série du cours. La bascule, la modale des jours (la première fois) et les streams sont ceux de la classe
# (UDR-0062 §3.4) : tout change en place, sans rechargement. La page d'un exercice (RE-22) porte les mêmes bascules : elle
# est prouvée au niveau contrôleur (budget de la suite système, ADR-0069 §9). Horloge : lundi 5 octobre 2026.
class Classroom::CatalogAssignmentTest < ApplicationSystemTestCase
  DAYS_MODAL = "turbo-frame#modal dialog[open]".freeze

  setup do
    travel_to Time.zone.local(2026, 10, 5, 10)
    tle = create_level(name: "Tle")
    @course = create_course(name: "Génétique", level: tle, series: create_series(name: "D"),
                            material: create_material(name: "SVT", category: "science"))
    @meiose = create_essential(course: @course, name: "Méiose")
    @phases = create_exercise(essential: @meiose, title: "Les phases")
    @bilan = create_exercise(essential: @meiose, title: "Le bilan")
    school = create_school
    @tle_d1, @tle_d2 = [ "Tle D 1", "Tle D 2" ].map { |name| create_classroom(school:, level: tle, series: @course.series, name:) }
    @tle_c1 = create_classroom(school:, level: tle, series: create_series(name: "C"), name: "Tle C 1")
    @teacher = create_teacher(school:, classrooms: [ @tle_d1, @tle_d2, @tle_c1 ])
    sign_in_as @teacher
    assert_current_path teacher_home_path
  end

  def toggle(classroom, exercise) = "#assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}"

  # PRD, chemin nominal enseignant, étape 4 ; plan, Lot F « Done quand ».
  test "from a catalogue sheet: the days modal the first time, then « Assigné · Pour jeu. 8 oct. » in place, Tle D 1 only" do
    visit course_essential_path(@course.slug, @meiose.slug)
    assert_selector "h1", text: "Méiose"
    assert_selector "#essential_exercises [id^='assignment_']", count: 4
    assert_no_selector "[id^='assignment_#{@tle_c1.public_id}_']"
    assert_no_text "Tle C 1"

    assert_no_page_reload do
      within(toggle(@tle_d1, @phases)) { click_on "Assigner" }
      within DAYS_MODAL do
        assert_selector "h2", text: "Quels jours voyez-vous la Tle D 1 ?"
        find("label", text: "Lun.").click
        find("label", text: "Jeu.").click
        click_on "Assigner"
      end
      assert_toast "Les phases ajouté à Tle D 1, à rendre jeudi 8 oct."
      assert_no_selector DAYS_MODAL
      within(toggle(@tle_d1, @phases)) do
        assert_text "Assigné"
        assert_text "Pour jeu. 8 oct."
        assert_button "Retirer"
      end
      within(toggle(@tle_d2, @phases)) { assert_no_text "Assigné" }

      # Les jours de Tle D 1 sont connus : la page rafraîchie par morphing, son « Assigner » suivant assigne en un clic.
      within(toggle(@tle_d1, @bilan)) { find_button("Assigner").click }
      assert_toast "Le bilan ajouté à Tle D 1, à rendre jeudi 8 oct."
      # Constat du challenger : la page vient d'être rafraîchie par morphing (le « Assigner » du bilan est devenu un bouton) ;
      # l'interrupteur clair / sombre de l'en-tête doit rester visible.
      assert_selector "header [role=switch][aria-label='#{I18n.t("shared.theme_switch.label")}']", visible: true, wait: 1
      assert_no_selector DAYS_MODAL
      # Tle D 2 n'a pas encore ses jours : sa bascule ouvre toujours la modale.
      within(toggle(@tle_d2, @bilan)) { click_on "Assigner" }
      assert_selector DAYS_MODAL, text: "Quels jours voyez-vous la Tle D 2 ?"
    end

    assert_equal [ [ @tle_d1.id, Date.new(2026, 10, 8) ] ] * 2,
                 Orm::ClassroomAssignment.where(status: "active").order(:id).pluck(:classroom_id, :due_on)
  end

  # La bascule la plus large (« Assigné · Pour … · Retirer ») passe sous le nom de la classe plutôt que de déborder.
  test "on a phone, the toggles go under the exercise title, inside their list, and the page does not scroll sideways" do
    create_assignment(classroom: @tle_d1, assignable: @phases, by: @teacher, due_on: Date.new(2026, 10, 8))
    with_mobile_viewport do
      visit course_essential_path(@course.slug, @meiose.slug)

      title = find("#essential_exercise_#{@phases.public_id} a", text: "Les phases")
      list = find("#essential_exercise_#{@phases.public_id} ul[aria-label]").rect
      assigned = find(toggle(@tle_d1, @phases), text: "Pour jeu. 8 oct.").rect
      assert_operator assigned.y, :>, title.rect.y
      assert_operator assigned.x + assigned.width, :<=, list.x + list.width, "la bascule déborde de sa liste"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
