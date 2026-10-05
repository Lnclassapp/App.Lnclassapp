require "application_system_test_case"

# CL-10, CL-04 — UDR-0027. L'enseignant ouvre sa classe : il voit le code en majuscules, le copie (toast « Code copié. »,
# presse-papiers en majuscules, contrôleur clipboard depuis UDR-0054) sans rechargement de page, et voit la liste de ses élèves. Le bouton du code de
# récupération vise la route de B8 ; son parcours complet est rejoué au Lot E. ADR-0072, UDR-0027 (amendée le
# 2026-10-02) : « Cours assignés » a disparu de la page. Lot E de fonctions-espace-eleve (UDR-0062 §3.4, §3.5) : ses jours
# de séance, ses exercices assignés et leurs comptes, le suivi qui nomme les seuls rendus en retard, le bloc « Cours ».
class Classroom::ClassroomPageTest < ApplicationSystemTestCase
  # L'accueil enseignant appartient au Lot D3 : tant qu'il n'est pas fusionné, un remplaçant répond là où la connexion
  # arrive, comme dans test/system/teams/schools_test.rb. Un contrôleur fusionné se charge seul, le remplaçant s'efface.
  unless Object.const_defined?("Classroom::TeacherHomesController")
    Classroom.const_set(:TeacherHomesController, Class.new(AuthenticatedController) { def show = render(html: "home", layout: true) })
  end

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: create_level(name: "Tle"), series: create_series(name: "D"), name: "Tle D 1",
                                  join_code: "kfm37", max_students: 60)
    @teacher = create_teacher(school:, classrooms: [ @classroom ])
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"))
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course: @course)), by: @teacher)
    @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    @koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    create_exercise_session(student: @awa, status: "completed", score_percent: 100)
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
    sign_in_as @teacher
  end

  def scope = "classroom.classrooms"

  test "l'enseignant voit le code en majuscules, le copie sans rechargement, et voit ses élèves" do
    visit classroom_path(@classroom.public_id)

    within "#classroom_header" do
      assert_selector "h1", text: "Tle D 1"
      assert_selector "#classroom_join_code", exact_text: "KFM37"
      assert_selector "#classroom_headcount", text: I18n.t("#{scope}.header.headcount", count: 2, max: 60)
    end
    assert_no_selector "#assigned_courses"
    assert_no_text "Cours assignés"
    assert_no_text "Génétique et évolution"
    assert_selector "#classroom_roster li", count: 2
    assert_selector "#student_#{@awa.public_id}", text: "Awa Bamba"
    assert_selector "#student_#{@awa.public_id}", text: "100 %"
    # UDR-0077 §3.4 : le code de récupération est dans le menu ⋮ de la ligne ; il ouvre toujours la modale du code.
    assert_no_selector "#student_#{@koffi.public_id} button", text: I18n.t("#{scope}.roster.issue_code")
    assert_no_page_reload do
      click_menu_action("#student_#{@koffi.public_id}", I18n.t("#{scope}.roster.issue_code"))
      assert_selector "turbo-frame#modal dialog#pin-recovery-code-modal[open]"
      assert_toast I18n.t("identity.pin_recovery_codes.create.issued")
      click_on I18n.t("identity.pin_recovery_codes.code.close")
    end

    assert_no_page_reload do
      click_on I18n.t("#{scope}.header.copy")

      assert_toast I18n.t("shared.clipboard.copied_code")
    end
    assert_equal "KFM37", page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
  end

  test "une copie refusée par le navigateur le dit, et le code reste lisible" do
    visit classroom_path(@classroom.public_id)
    page.execute_script("navigator.clipboard.writeText = () => Promise.reject(new Error('refusé'))")

    click_on I18n.t("#{scope}.header.copy")

    assert_toast I18n.t("shared.clipboard.failed")
    assert_no_selector "#toasts", text: I18n.t("shared.clipboard.copied_code")
    assert_selector "#classroom_join_code", exact_text: "KFM37"
  end

  test "sur un téléphone, la page tient dans la largeur et le code se copie" do
    with_mobile_viewport do
      visit classroom_path(@classroom.public_id)

      assert_selector "#classroom_join_code", exact_text: "KFM37"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
      click_on I18n.t("#{scope}.header.copy")
      assert_toast I18n.t("shared.clipboard.copied_code")
      assert find_link(I18n.t("#{scope}.header.share_whatsapp"))[:href].start_with?("https://wa.me/?text=")
      growth_shot("390-classe-partager-whatsapp", desktop: false, scroll_to: "#classroom_whatsapp_share")
    end
  end

  test "CP-08: le lien de la classe se partage sur WhatsApp, avec un message prêt pour le groupe de la classe" do
    visit classroom_path(@classroom.public_id)

    share = find_link(I18n.t("#{scope}.header.share_whatsapp"))
    text = CGI.unescape(share[:href].delete_prefix("https://wa.me/?text="))
    assert_includes text, "Tle D 1"
    assert_includes text, "/c/KFM37"
    assert_includes text, "KFM37"
    assert_no_match(/Awa|Bamba|Koffi|Yao/, text)
    growth_shot("1280-classe-partager-whatsapp", scroll_to: "#classroom_header")
  end

  test "l'enseignant lit ses jours, le suivi d'un exercice qui nomme les seuls rendus en retard, et ouvre un cours de sa classe" do
    [ 1, 4 ].each { Orm::ClassroomSessionDay.create!(teacher: @teacher, classroom: @classroom, weekday: it) }
    svt = Orm::TeacherProfile.find_by!(user: @teacher).material
    tle_course = create_course(level: @classroom.level, series: @classroom.series, material: svt, name: "La cellule")
    essential = create_essential(course: tle_course, name: "La mitose")
    exercise = create_exercise(essential:, title: "Phases de la mitose")
    assignment = travel_to(Time.zone.local(2026, 10, 5, 9)) do
      create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, due_on: Date.new(2026, 10, 8))
    end
    create_exercise_session(student: @koffi, exercise:, status: "completed", classroom_assignment: assignment,
                            completed_at: Time.zone.local(2026, 10, 9, 10))

    visit classroom_path(@classroom.public_id)

    assert_selector "#classroom_session_days", text: "Vos jours de séance : lundi, jeudi"
    within "#assignment_#{assignment.public_id}" do
      assert_text "Pour jeu. 8 oct."
      assert_text "1 fait, dont 1 en retard · 1 pas encore fait"
    end
    within("#assignment_#{assignment.public_id}") { click_on "Phases de la mitose" }

    assert_current_path classroom_assignment_path(@classroom.public_id, assignment.public_id)
    assert_selector "h1", text: "Phases de la mitose"
    within "#late_students" do
      assert_selector "li", count: 1
      assert_text "Koffi Yao"
      assert_text "Fait le ven. 9 oct."
      assert_no_text "Awa Bamba"
    end
    # ADR-0079 §4.8 : Awa n'a pas encore fait l'exercice ; elle est nommée pour être relancée, jamais parmi les retards.
    within("#pending_students") { assert_text "Awa Bamba" }

    click_on "Tle D 1"
    within("#classroom_courses") { click_on "La cellule" }
    assert_current_path classroom_course_path(@classroom.public_id, tle_course.slug)
    assert_selector "#classroom_course_essentials a", text: "La mitose"
  end

  test "sur un téléphone, les blocs de la classe et le suivi tiennent dans la largeur" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(title: "Un titre d'exercice assez long pour un écran étroit"),
                                   by: @teacher)
    svt = Orm::TeacherProfile.find_by!(user: @teacher).material
    3.times { create_course(level: @classroom.level, series: @classroom.series, material: svt, name: "Cours de la bande #{it}") }
    with_mobile_viewport do
      visit classroom_path(@classroom.public_id)

      assert_selector "#classroom_session_days", text: I18n.t("#{scope}.session_days.unset")
      assert_selector "#assignment_#{assignment.public_id}", text: "0 fait · 2 pas encore faits"
      # UDR-0077 §3.4 : les cours en bande, avant les exercices ; ⋮ de l'élève sur la ligne de son nom.
      assert_operator find("#classroom_courses").rect.y, :<, find("#assigned_exercises").rect.y
      assert_selector "#classroom_courses ul[data-communication--carousel-target=track] > li", count: 3
      within("#student_#{@koffi.public_id}") do
        avatar = find(".rounded-full.shrink-0", match: :first).rect
        menu = find("button[aria-haspopup=menu]").rect
        assert_in_delta avatar.y + (avatar.height / 2), menu.y + (menu.height / 2), 8, "⋮ n'est pas sur la ligne de l'élève"
        # « Aucune session terminée » ne doit pas écraser le nom.
        assert_selector "p", exact_text: "Koffi Yao"
        name = find("p", exact_text: "Koffi Yao")
        assert_equal name.evaluate_script("this.scrollWidth"), name.evaluate_script("this.clientWidth"), "le nom est tronqué"
      end
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page de la classe déborde en largeur"

      visit classroom_assignment_path(@classroom.public_id, assignment.public_id)
      assert_text I18n.t("classroom.assignment_follow_ups.show.no_due_date")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "le suivi déborde en largeur"
    end
  end
end
