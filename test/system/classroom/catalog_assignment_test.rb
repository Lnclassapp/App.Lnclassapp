require "application_system_test_case"

# RE-21, RE-23 (UDR-0069 §3.8) : depuis une fiche du catalogue, l'enseignant assigne un exercice à l'une de ses classes du
# niveau et de la série du cours. La bascule, la modale des jours (la première fois) et les streams sont ceux de la classe
# (UDR-0062 §3.4) : tout change en place, sans rechargement. Lot L (UDR enseignant §3.13) : un seul « Assigner » plein, plus de
# « Plus tard » (sans jour, 422 avec l'erreur), « Prochaine séance : … », puis « Modifier les jours de la … » qui les remplace. La page d'un exercice (RE-22) porte les mêmes bascules : elle
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
    visit course_path(@course.slug)
    assert_selector "h1", text: "Génétique"
    assert_selector "#prepare-interros [id^='assignment_']", count: 4
    assert_no_selector "[id^='assignment_#{@tle_c1.public_id}_']"
    assert_no_text "Tle C 1"
    assert_selector "#prepare-interros .ui-button-primary", count: 1
    assert_selector "#{toggle(@tle_d1, @phases)} .ui-button-primary"

    assert_no_page_reload do
      within(toggle(@tle_d1, @phases)) { click_on "Assigner" }
      within DAYS_MODAL do
        assert_selector "h2", text: "Quels jours voyez-vous la Tle D 1 ?"
        assert_no_text "Plus tard"
        assert_no_text "Prochaine séance"
        click_on "Assigner" # sans jour : refusé, l'erreur sous les jours, rien d'écrit
        assert_selector "#assignment_weekdays_error", text: "Cochez au moins un jour."
        find("label", text: "Lun.").click
        find("label", text: "Jeu.").click
        assert_text "Prochaine séance : jeudi 8 oct."
        assert_no_selector "#assignment_weekdays_error" # un jour coché efface l'erreur
        %w[Lun. Jeu.].each { find("label", text: it).click }
        assert_selector "#assignment_weekdays_error" # tout décocher la rétablit
        %w[Lun. Jeu.].each { find("label", text: it).click }
        click_on "Assigner"
      end
      assert_toast "Les phases ajouté à Tle D 1, à rendre jeudi 8 oct."
      assert_no_selector DAYS_MODAL
      # UDR-0077 §3.3 : la ligne compacte entière est remplacée — l'échéance sous la classe, ✕ seul à droite.
      within(toggle(@tle_d1, @phases)) do
        assert_text "Assigné"
        assert_selector "p.text-xs", text: "Pour jeu. 8 oct."
        assert_selector "button[aria-label='Retirer « Les phases » de Tle D 1']"
      end
      within(toggle(@tle_d2, @phases)) { assert_no_text "Assigné" }

      # Les jours de Tle D 1 sont connus : la page rafraîchie par morphing, son « Assigner » suivant assigne en un clic.
      within(toggle(@tle_d1, @bilan)) { find_button("Assigner").click }
      assert_toast "Le bilan ajouté à Tle D 1, à rendre jeudi 8 oct."
      dismiss_toasts # le toast couvrirait l'« Assigner » de Tle D 2, en bas à droite
      # Constat du challenger : la page vient d'être rafraîchie par morphing (le « Assigner » du bilan est devenu un bouton) ;
      # l'avatar de l'en-tête (le mode sombre est dans « Mon compte », plus de lune) doit rester visible.
      assert_selector "header a[aria-controls=account_panel]", visible: true, wait: 1
      assert_no_selector DAYS_MODAL
      # Tle D 2 n'a pas encore ses jours : sa bascule ouvre toujours la modale.
      within(toggle(@tle_d2, @bilan)) { click_on "Assigner" }
      assert_selector DAYS_MODAL, text: "Quels jours voyez-vous la Tle D 2 ?"
      within(DAYS_MODAL) { click_on "Annuler" } # ferme sans rien écrire
      assert_no_selector DAYS_MODAL
      # CA-L4 : la fenêtre des jours de Tle D 1 (bouton de la page de la classe) rouvre avec ses jours cochés ; « Enregistrer » les remplace.
      open_in_modal edit_classroom_session_days_path(@tle_d1.public_id)
      within DAYS_MODAL do
        assert_equal %w[session_days_weekdays_1 session_days_weekdays_4],
                     all("input[type=checkbox]:checked", visible: :all).map { it[:id] }
        find("label", text: "Ven.").click
        click_on "Enregistrer"
      end
      assert_toast "Jours de séance enregistrés."
      assert_no_selector DAYS_MODAL
    end

    assert_equal [ [ @tle_d1.id, Date.new(2026, 10, 8) ] ] * 2,
                 Orm::ClassroomAssignment.where(status: "active").order(:id).pluck(:classroom_id, :due_on)
    assert_equal [ 1, 4, 5 ], Orm::ClassroomSessionDay.where(teacher_id: @teacher.id, classroom_id: @tle_d1.id).pluck(:weekday).sort
  end

  # CA-7 (UDR-0077 §3.3) : à 375 px, la ligne d'une classe tient sur une ligne — la classe à gauche, « Assigné » et ✕ à
  # droite, l'échéance sous la classe — sous le titre de l'exercice, dans sa liste, sans défilement de côté.
  test "on a phone, each classroom is one compact row under the exercise title, and the page does not scroll sideways" do
    create_assignment(classroom: @tle_d1, assignable: @phases, by: @teacher, due_on: Date.new(2026, 10, 8))
    with_mobile_viewport do
      visit course_path(@course.slug)

      title = find("#exercise-#{@phases.public_id} a", text: "Les phases")
      list = find("#exercise-#{@phases.public_id} ul").rect
      assigned = find(toggle(@tle_d1, @phases), text: "Pour jeu. 8 oct.").rect
      assert_operator assigned.y, :>, title.rect.y
      assert_operator assigned.x + assigned.width, :<=, list.x + list.width, "la bascule déborde de sa liste"
      within(toggle(@tle_d1, @phases)) do
        name = find("p", text: "Tle D 1").rect
        cross = find("button[aria-label='Retirer « Les phases » de Tle D 1']").rect
        assert_operator cross.y, :<, name.y + name.height, "✕ passe sous le nom de la classe"
        assert_operator cross.x, :>, name.x + name.width, "✕ n'est pas à droite de la classe"
        assert_operator cross.height, :>=, 48
      end
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
