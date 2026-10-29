require "application_system_test_case"

# CA-16 (accueil-eleve, ADR-0089 §4.2, UDR-0084 §3.7) : sur la page de sa classe, l'enseignant lit « Fait seul (7 j) ». À
# l'ordinateur, une colonne à côté du dernier score, « — » pour 0 ; au téléphone (390 px), rien de tel (maquette 10 : la ligne
# n'a que le nom, « N faits sur M » et le badge), sans défilement horizontal. Les comptes de l'exercice donné ne bougent pas.
class Classroom::ClassroomRosterTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    school = create_school(name: "Lycée Moderne de Cocody")
    @classroom = create_classroom(school:, level: create_level(name: "6ème"), name: "6ème 2")
    @teacher = create_teacher(school:, classrooms: [ @classroom ])
    exercise = create_exercise(title: "Les fractions")
    @assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", joined_at: 1.month.ago)
    @koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao", joined_at: 1.month.ago)
    create_exercise_session(student: @koffi, exercise:, status: "completed", score_percent: 80, classroom_assignment: @assignment)
    [ 3, 1 ].each do |days|
      create_exercise_session(student: @awa, status: "completed", score_percent: 70, started_at: days.days.ago,
                              completed_at: days.days.ago)
    end
    create_exercise_session(student: @awa, status: "completed", started_at: 8.days.ago, completed_at: 8.days.ago)
  end

  test "CA-16 : la colonne « Fait seul (7 j) » à l'ordinateur, rien de tel à 390 px" do
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id, q: "a")

    assert_selector "#self_practice_heading", text: "Fait seul (7 j)", wait: SIGN_IN_WAIT
    assert_selector "#self_practice_#{@awa.public_id}", text: /Fait seul \(7 j\)\s+2/
    assert_selector "#self_practice_#{@koffi.public_id} span.text-mute", text: "—"
    assert_selector "#assignment_#{@assignment.public_id}", text: "1 / 2 fait"
    growth_shot("lot-d-classroom-roster-1280", scroll_to: "#classroom_roster")

    with_mobile_viewport do
      assert_no_text "Fait seul :"
      assert_no_selector "#self_practice_#{@awa.public_id}"
      assert_no_selector "#self_practice_heading"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                      page.evaluate_script("document.documentElement.clientWidth")
      growth_shot("lot-d-classroom-roster-390", scroll_to: "#classroom_roster", desktop: false)
    end
  end

  # rapports-de-classe, Lot B (CL-15 ; ADR-0097 §4.7) et UDR enseignant §3.5 (Lot I) : la liste filtrée par badge, « Tous » ouvert ;
  # trente élèves puis « Voir les suivants » sans recharger la page ; le nom ouvre la fiche.
  test "CL-15 : un filtre par badge, trente par trente, puis la fiche d'un élève" do
    64.times { |index| create_student(classroom: @classroom, first_name: format("N%02d", index), last_name: "Élève", joined_at: 1.month.ago) }
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)

    assert_selector "#classroom_roster_badge_all[aria-current=true]", wait: SIGN_IN_WAIT
    assert_selector "#classroom_roster_count", text: "30 sur 66"

    assert_no_page_reload do
      click_on "classroom_roster_badge_gold"
      assert_selector "#classroom_roster_list li[id^=student_]", count: 1
      assert_selector "#student_#{@koffi.public_id}", text: "Moyenne 16/20 · Or"
      click_on "classroom_roster_badge_none"
      assert_selector "#classroom_roster_count", text: "30 sur 65"
      click_on I18n.t("classroom.classrooms.roster.more", count: 30)
      assert_selector "#classroom_roster_count", text: "60 sur 65"
      click_on I18n.t("classroom.classrooms.roster.more", count: 5)
      # Le cadre est remplacé : on attend son compteur complet, qui n'existe qu'après le remplacement, avant de compter les lignes.
      assert_selector "#classroom_roster_count", text: "65 élèves", wait: SIGN_IN_WAIT
      assert_no_selector "#classroom_roster_more"
      assert_selector "#classroom_roster_list li[id^=student_]", count: 65
    end
    with_mobile_viewport do
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                      page.evaluate_script("document.documentElement.clientWidth")
    end

    within("#student_#{@awa.public_id}") { click_on "Awa Bamba" }
    assert_selector "h1", text: "Awa Bamba"
    assert_current_path classroom_student_path(@classroom.public_id, @awa.public_id)
  end
end
