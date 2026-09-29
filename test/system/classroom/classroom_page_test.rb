require "application_system_test_case"

# CL-10, CL-04 — UDR-0027. L'enseignant ouvre sa classe : il voit le code en majuscules, le copie (toast « Code copié. »,
# presse-papiers en majuscules, contrôleur clipboard depuis UDR-0054) sans rechargement de page, et voit la liste de ses élèves. Le bouton du code de
# récupération vise la route de B8 ; son parcours complet est rejoué au Lot E.
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
    create_assignment(classroom: @classroom, assignable: @course, by: @teacher)
    create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
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
    assert_selector "#assigned_courses li", count: 1
    assert_selector "#assigned_courses", text: "Génétique et évolution"
    assert_selector "#classroom_roster li", count: 2
    assert_selector "#student_#{@awa.public_id}", text: "Awa Bamba"
    assert_selector "#student_#{@awa.public_id}", text: "100 %"
    assert_selector "#student_#{@koffi.public_id} button", text: I18n.t("#{scope}.roster.issue_code")

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
end
