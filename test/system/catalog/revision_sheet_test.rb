require "application_system_test_case"

# CA-12 dans un navigateur, UDR-0139 §3.3 — ce que seul un navigateur juge : la suite masquée au chargement, « Voir plus » qui la
# déplie sans requête, « Voir moins » qui la replie et rend le focus au bouton, la fiche à 390 px. Le rendu serveur (coupe, `rest`,
# absence de `hidden`) est jugé par test/integration/catalog/revision_sheet_test.rb.
class Catalog::RevisionSheetSystemTest < ApplicationSystemTestCase
  BUTTON = "[data-catalog--revision-more-target='button']".freeze
  REST = "[data-catalog--revision-more-target='rest']".freeze

  setup do
    @course = create_course(name: "Racines carrées", content: "", sheet_theme: "teal")
    @student = create_student_for(@course)
    long = revision_notion("Notion longue").merge("remember" => Array.new(160) { "mot" }.join(" "))
    [ long, revision_notion("Seconde notion") ].each do |notion|
      sheet = { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"], "pitfall" => notion["pitfall"] }
      create_essential(course: @course, name: notion["name"], sheet:)
    end
  end

  def more = I18n.t("catalog.courses.show.revision_more")
  def less = I18n.t("catalog.courses.show.revision_less")
  def shown = I18n.t("catalog.courses.show.revision_shown")
  def requests = page.evaluate_script("performance.getEntriesByType('resource').filter((e) => ['fetch', 'xmlhttprequest'].includes(e.initiatorType)).length")
  def focused_in_rest? = page.evaluate_script("document.activeElement.matches(\"#{REST}\")")
  def focused_button? = page.evaluate_script("document.activeElement === document.querySelector(\"#{BUTTON}\")")
  def no_sideways_scroll? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  test "the student unfolds the sheet in place, folds it back and gets the focus on the button" do
    sign_in_as @student

    # Une adresse sur #fiche-de-revision garde la fiche repliée (UDR-0139 §3.3).
    visit course_path(@course.slug, anchor: "fiche-de-revision")

    assert_selector "section#fiche-de-revision h2", text: "Fiche de révision"
    assert_selector ".sheet-box[data-tone='remember']", count: 1
    assert_no_selector "h4", text: "Seconde notion"
    assert_selector BUTTON, text: more
    assert_equal "false", find(BUTTON)["aria-expanded"]
    assert_selector ".revision-fade"

    assert_no_page_reload do
      before = requests
      find(BUTTON).click

      assert_selector "h4", text: "Seconde notion"
      assert_selector ".sheet-box[data-tone='pitfall']", count: 2
      assert_selector BUTTON, text: less
      assert_equal "true", find(BUTTON)["aria-expanded"]
      assert_no_selector ".revision-fade"
      assert focused_in_rest?, "le focus va au premier élément déplié"
      assert_equal shown, find("[data-catalog--revision-more-target='status']", visible: :all)[:textContent]
      assert_equal before, requests, "« Voir plus » n'envoie aucune requête"
    end

    find(BUTTON).click

    assert_no_selector "h4", text: "Seconde notion"
    assert_selector BUTTON, text: more
    assert focused_button?, "le focus revient au bouton"
  end

  test "on a phone, the folded sheet fits the screen and « Voir plus » is a 48 px target" do
    sign_in_as @student

    with_mobile_viewport do
      visit course_path(@course.slug)

      assert_selector BUTTON, text: more
      assert_operator find(BUTTON).native.size.height, :>=, 48
      assert no_sideways_scroll?, "la page défile sur le côté"
      find(BUTTON).click
      assert_selector "h4", text: "Seconde notion"
      assert no_sideways_scroll?, "la page défile sur le côté, dépliée"
    end
  end
end
