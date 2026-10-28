require "application_system_test_case"

# CA-01 et CA-02 dans un navigateur, UDR-0139 §3.3 — ce que seul un navigateur juge : la suite masquée au chargement, « Voir plus »
# qui la déplie sans requête, « Voir moins » qui la replie et rend le focus au bouton, la figure interactive dépliée qui répond
# au clavier, le texte des notions. Le rendu serveur (coupe, `rest`, absence de `hidden`) est jugé par
# test/integration/catalog/revision_sheet_test.rb.
class Catalog::RevisionSheetSystemTest < ApplicationSystemTestCase
  FIGURE = { "type" => "media", "kind" => "thales_figure" }.freeze
  BUTTON = "[data-catalog--revision-more-target='button']".freeze

  setup do
    @course = create_course(name: "Propriétés de Thalès", content: "")
    @student = create_student_for(@course)
  end

  def words(count, prefix) = Array.new(count) { prefix }.join(" ")
  def more = I18n.t("catalog.courses.show.revision_more")
  def less = I18n.t("catalog.courses.show.revision_less")
  def shown = I18n.t("catalog.courses.show.revision_shown")
  def requests = page.evaluate_script("performance.getEntriesByType('resource').filter((e) => ['fetch', 'xmlhttprequest'].includes(e.initiatorType)).length")
  def focused_in_rest? = page.evaluate_script("document.activeElement.matches(\"[data-catalog--revision-more-target='rest']\")")
  def focused_button? = page.evaluate_script("document.activeElement === document.querySelector(\"#{BUTTON}\")")

  def sheet_document
    paragraphs = (0..5).map { { "type" => "paragraph", "text" => "#{words(100, "mot#{it}")} fin#{it}" } }
    { "pages" => [ { "sections" => [ { "title" => "Le cours", "blocks" => paragraphs + [ FIGURE ] } ] } ], "glossary" => {} }
  end

  test "the student unfolds the sheet in place, uses the figure, folds it back and gets the focus on the button" do
    create_course_sheet(course: @course, document: sheet_document)
    sign_in_as @student

    # Une adresse sur #fiche-de-revision garde la fiche repliée (UDR-0139 §3.3).
    visit course_path(@course.slug, anchor: "fiche-de-revision")

    assert_selector "section#fiche-de-revision h2", text: "Fiche de révision"
    assert_selector "p.sheet-text", count: 2
    assert_selector "p.sheet-text", visible: :all, count: 6
    assert_no_selector ".sheet-thales-svg"
    assert_selector BUTTON, text: more
    assert_equal "false", find(BUTTON)["aria-expanded"]
    assert_selector ".revision-fade"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"

    assert_no_page_reload do
      before = requests
      find(BUTTON).click

      assert_selector "p.sheet-text", count: 6
      assert_selector ".sheet-thales-svg"
      assert_selector BUTTON, text: less
      assert_equal "true", find(BUTTON)["aria-expanded"]
      assert_no_selector ".revision-fade"
      assert focused_in_rest?, "le focus va au premier élément déplié"
      assert_equal shown, find("[data-catalog--revision-more-target='status']", visible: :all)[:textContent]
      assert_equal before, requests, "« Voir plus » n'envoie aucune requête"
    end

    dot = find(".sheet-thales-dot[data-point='A']")
    x = dot[:cx].to_f
    find(".sheet-thales-hit[data-point='A']").send_keys(:arrow_right)
    assert_operator find(".sheet-thales-dot[data-point='A']")[:cx].to_f, :>, x

    find(BUTTON).click

    assert_selector "p.sheet-text", count: 2
    assert_no_selector ".sheet-thales-svg"
    assert_selector BUTTON, text: more
    assert_equal "false", find(BUTTON)["aria-expanded"]
    assert focused_button?, "le focus revient au bouton"
  end

  test "on a phone, the folded sheet fits the screen and « Voir plus » is a 48 px target" do
    create_course_sheet(course: @course, document: sheet_document)
    sign_in_as @student

    with_mobile_viewport do
      visit course_path(@course.slug)

      assert_selector BUTTON, text: more
      assert_operator find(BUTTON).native.size.height, :>=, 48
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"
      find(BUTTON).click
      assert_selector "p.sheet-text", count: 6
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté, dépliée"
    end
  end

  test "without a sheet, the text of the lesson and of its notions folds and unfolds the same way" do
    @course.update!(content: "<p>#{words(100, "intro")} fin0</p><p>#{words(60, "suite")} fin1</p>")
    create_essential(course: @course, name: "Première notion", content: "<p>Texte de la première notion.</p>")
    sign_in_as @student

    visit course_path(@course.slug)

    assert_text "fin1"
    within("section#fiche-de-revision") { assert_no_text "Première notion" }
    assert_selector BUTTON, text: more

    find(BUTTON).click

    assert_selector "section#fiche-de-revision h3", text: "Première notion"
    assert_text "Texte de la première notion."
    assert_selector BUTTON, text: less

    find(BUTTON).click

    within("section#fiche-de-revision") { assert_no_text "Première notion" }
    assert focused_button?
  end
end
