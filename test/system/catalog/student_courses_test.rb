require "application_system_test_case"

# Chantier cours-eleve — UDR-0085, ADR-0090. La page Cours de l'élève : groupes par matière dans l'ordre du programme,
# recherche seule, vue d'une matière (titre d'un groupe, bulle de l'accueil), pagination sans titre répété, et le bouton
# qui dit où il en est, « Reprendre » rouvrant la dernière fiche ouverte.
class Catalog::StudentCoursesTest < ApplicationSystemTestCase
  setup do
    @level = create_level(name: "6e")
    @maths = create_material(name: "Mathématiques")
    @svt = create_material(name: "SVT")
    @french = create_material(name: "Français", category: "literature")
    @fractions = create_course(name: "Les fractions", level: @level, material: @maths)
    @cell = create_course(name: "La cellule", level: @level, material: @svt)
    create_course(name: "Le résumé", level: @level, material: @french)
    @student = create_student(classroom: create_classroom(level: @level))
  end

  def t(key, **) = I18n.t(key, **)
  def group_ids = all("#courses_groups > section").map { it[:id] }

  # CA-1, CA-4, CA-5, CA-13, CA-14 à 390 px.
  test "on a phone, the student reads the groups in program order, searches, and opens the view of a subject" do
    sign_in_as @student

    with_mobile_viewport do
      visit courses_path
      assert_equal %w[courses_group_mathematiques courses_group_svt courses_group_francais], group_ids
      assert_no_link t("catalog.courses.index.reset")
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"

      assert_no_page_reload do
        fill_in t("catalog.courses.index.filters.search"), with: "fraction"
        assert_selector "#courses_groups li", count: 1
        assert_equal %w[courses_group_mathematiques], group_ids
        assert_link t("catalog.courses.index.reset")

        fill_in t("catalog.courses.index.filters.search"), with: "zzz"
        assert_selector "#courses_empty", text: t("catalog.courses.index.student_no_match_description")
      end

      visit courses_path
      find("#courses_group_svt_title a").click
      assert_selector "#courses_material_title h1", text: "SVT"
      assert_selector "#courses_groups li", count: 1
      assert_no_selector "#courses_groups h2"

      visit student_home_path
      find("#subject_svt").click
      assert_selector "#courses_material_title h1", text: "SVT"
      assert_current_path courses_path(material: "svt")
    end
  end

  # CA-7, CA-15 : une fiche ouverte fait « Reprendre » ; la page suivante ne répète pas le titre du groupe. Lot O5 : ce Cours
  # est celui du téléphone ; sur ordinateur, les leçons en cartes le remplacent (test ci-dessous).
  test "on a phone, an opened sheet turns the card into « Reprendre », and the next page does not repeat a title" do
    sheet = create_essential(course: @fractions, name: "Simplifier une fraction")
    create_essential(course: @fractions, name: "Comparer des fractions")
    25.times { |index| create_course(name: format("Thalès %02d", index), level: @level, material: @maths) }
    sign_in_as @student

    with_mobile_viewport do
      visit course_essential_path(@fractions.slug, sheet.slug)
      assert_selector "#essential_header h1", text: "Simplifier une fraction"

      visit courses_path
      assert_selector "#courses_groups li", count: 24
      within("#course_#{@fractions.slug}") { click_on t("catalog.courses.course_card.progress.started") }
      assert_selector "#essential_header h1", text: "Simplifier une fraction"

      visit courses_path
      assert_no_page_reload do
        scroll_to find("turbo-frame#courses_page_2")
        assert_selector "#courses_groups_page_2 li", count: 4
      end
      assert_selector "h2#courses_group_mathematiques_title", count: 1
      assert_selector "#courses_groups_page_2 section", count: 2
    end
  end

  # Lot O5, CA-E14 et CA-E15 : Cours par leçons sur ordinateur (1400 px) ; à 390 px, le Cours de CA-E6 reste.
  test "on a computer, the lessons of one subject are cards on two columns with their sheets; on a phone Cours stays the same" do
    create_course(name: "Les angles", level: @level, material: @maths)
    sheets = Array.new(5) { |index| create_essential(course: @fractions, name: "Fiche #{index + 1}") }
    create_gap(student: @student, essential: sheets.second)
    sign_in_as @student

    visit courses_path
    assert_selector "#lesson_materials a[aria-current=page]", text: "Mathématiques"
    assert_selector "#lesson_materials a", count: 3
    assert_selector "#lessons_list > li", count: 2
    columns = all("#lessons_list > li").map { it.evaluate_script("this.getBoundingClientRect().x").round }
    assert_equal 2, columns.uniq.size, "deux colonnes"
    within("#lesson_#{@fractions.slug}") do
      assert_selector "li[id^=lesson_essential_]", count: 3, visible: :visible
      assert_selector "li[id^=lesson_essential_]", text: t("catalog.courses.essential_row.review"), count: 1
      click_on t("catalog.courses.course_card.more_essentials", count: 5)
      assert_selector "li[id^=lesson_essential_]", count: 5
    end

    click_on "SVT"
    assert_current_path courses_path(material: "svt")
    assert_selector "#lesson_materials a[aria-current=page]", text: "SVT"
    visit courses_path
    assert_selector "#lesson_materials a[aria-current=page]", text: "SVT"

    with_mobile_viewport do
      visit courses_path
      assert_selector "#courses_groups > section", count: 3
      assert_no_selector "#lesson_materials"
      assert_selector "#courses_total", text: "Progression DPFC", count: 1
    end
  end
end
