require "application_system_test_case"

# CA-5, CA-6 — la fiche de cours se lit dans un vrai navigateur : 3 pages, mot du lexique en bulle (titre, définition,
# exemple), « Lexique » qui liste tous les mots, bulle fermée au clic ailleurs et au défilement, « Explications simples »
# qui se masquent et se montrent, formules rendues par KaTeX.
class Catalog::CourseSheetReadingTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Propriétés de Thalès")
    create_course_sheet(course: @course, document: reading_course_sheet_document)
    sign_in_as create_student_for(@course)
    visit course_sheet_path(@course.slug)
  end

  def t(key, **) = I18n.t("catalog.course_sheets.#{key}", **)

  test "the student reads three pages and the formulas are rendered" do
    assert_selector "[data-screen-label]", count: 3
    assert_selector "[data-screen-label='Page 1'] h1", text: "La propriété de Thalès"
    assert_selector ".sheet-box .katex"
    assert_selector "[data-screen-label='Page 3'] .sheet-page-footer", text: "3 / 3"
  end

  test "a touched word opens its bubble, and a click elsewhere closes it" do
    first(".sheet-intro .sheet-word", text: "sécantes").click

    assert_selector ".sheet-bubble", visible: :visible
    within(".sheet-bubble") do
      assert_text "Sécantes"
      assert_text "Deux droites sont sécantes quand elles se croisent en un point."
      assert_text "Comme deux routes qui se croisent à un carrefour."
    end

    find(".sheet-h1").click

    assert_no_selector ".sheet-bubble"
  end

  test "the bubble closes when the page scrolls" do
    first(".sheet-intro .sheet-word", text: "sécantes").click
    assert_selector ".sheet-bubble"

    page.execute_script("window.scrollBy(0, 300)")

    assert_no_selector ".sheet-bubble"
  end

  test "« Lexique » lists every word, and a word opens its explanation" do
    click_on t("glossary.button")

    within(".sheet-bubble") do
      assert_text t("glossary.button")
      assert_selector ".sheet-bubble-term", count: 3
      click_on "Hypothèse"

      assert_text "Une information que l'énoncé te donne."
    end
  end

  test "the help opens from the hint" do
    click_on t("glossary.hint")

    within(".sheet-bubble") { assert_text t("glossary.help_title") }
  end

  test "the simple explanations hide and show again" do
    assert_selector ".sheet-simple", text: "Le petit triangle AMN"

    click_on t("simple.label_on")

    assert_no_selector ".sheet-simple"
    assert_selector "button[aria-pressed='false']", text: t("simple.label_off")

    click_on t("simple.label_off")

    assert_selector ".sheet-simple", text: "Le petit triangle AMN"
  end
end
