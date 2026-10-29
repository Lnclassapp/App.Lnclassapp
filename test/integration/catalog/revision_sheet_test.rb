require "test_helper"

# CA-12, CA-13 (description) et CA-14 — UDR-XXXX §3.1, §3.2 et UDR-0139 §3.2. La fiche de révision d'une leçon v3 dans la page de la
# leçon : une page de cahier, une section par notion, quatre blocs dans l'ordre, étapes numérotées, coupe des 150 mots toute présente
# dans le HTML.
class Catalog::RevisionSheetTest < ActionDispatch::IntegrationTest
  REST = "[data-catalog--revision-more-target='rest']".freeze

  setup do
    @course = create_course(name: "Racines carrées", subtitle: "Calculer et simplifier", sheet_theme: "teal", figures: [ revision_figure ], content: "")
    @student = create_student_for(@course)
  end

  def words(count) = Array.new(count) { "mot" }.join(" ")

  def add_notion(notion, **attributes)
    sheet = { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"],
              "pitfall" => notion["pitfall"], "figure_key" => notion["figure"] }
    create_essential(course: @course, name: notion["name"], sheet:, **attributes)
  end

  def open_course(user = @student)
    sign_in_as user
    get course_path(@course.slug)
    assert_response :success
  end

  def t(key, **) = I18n.t("catalog.courses.show.#{key}", **)
  def sheet_t(key, **) = I18n.t("catalog.revision_sheets.sheet.#{key}", **)

  test "CA-12: each notion shows its four blocks in order on the notebook, at the theme of the lesson" do
    add_notion(revision_notion("Simplifier une racine carrée", figure: "triangle-thales"))
    add_notion(revision_notion("Calculer avec des racines"))

    open_course

    assert_select "section#fiche-de-revision h2", text: t("revision_title")
    assert_operator response.body.index("id=\"fiche-de-revision\""), :<, response.body.index("id=\"prepare-interros\"")
    assert_select "section#fiche-de-revision .sheet-screen[data-sheet-theme='teal'][data-seyes='true'][data-embedded='true'][data-controller='math']"
    assert_select ".sheet-screen article.sheet-page", count: 1
    assert_select ".sheet-eyebrow", text: /#{@course.material.name} · #{@course.level.name}.*#{sheet_t("eyebrow")}/m
    assert_select "h3.sheet-h1", text: "Racines carrées"
    assert_select "p.sheet-intro", text: "Calculer et simplifier"
    assert_select "section.sheet-section", count: 2
    assert_select "section.sheet-section#notion-racines-carrees-simplifier-une-racine-carree[aria-labelledby='notion-racines-carrees-simplifier-une-racine-carree-title']" do
      assert_select "h4.sheet-h2#notion-racines-carrees-simplifier-une-racine-carree-title", text: "1. Simplifier une racine carrée"
      section = css_select("section.sheet-section").first
      labels = section.css(".sheet-box-label, .sheet-card-title").map { it.text.strip }
      assert_equal [ sheet_t("remember"), sheet_t("method"), sheet_t("example"), sheet_t("pitfall") ], labels
      tones = section.css(".sheet-box").map { it["data-tone"] }
      assert_equal %w[remember method pitfall], tones
    end
    assert_select "h4.sheet-h2", text: "2. Calculer avec des racines"
    assert_select "footer.sheet-page-footer", text: "Racines carrées"
  end

  test "CA-12: the steps of the method are numbered and each step of the example carries the number of the step it applies" do
    add_notion(revision_notion("Simplifier une racine carrée"))

    open_course

    assert_select ".sheet-box[data-tone='method'] ol.sheet-steps li", count: 3
    assert_select ".sheet-box[data-tone='method'] ol.sheet-steps li:first-child .sr-only", text: sheet_t("step", number: 1)
    assert_select ".sheet-card ol.sheet-steps[data-applies='method'] li", count: 3
    assert_select ".sheet-card ol.sheet-steps[data-applies='method'] li:nth-child(3) .sr-only", text: sheet_t("step", number: 3)
    assert_select ".sheet-card p.sheet-text", text: /Simplifier/
    assert_select ".sheet-box[data-tone='remember'] .sheet-text", text: /Pour \$a/
    assert_select ".sheet-box[data-tone='pitfall'] .sheet-text", text: /ne se distribue pas/
  end

  test "CA-13: the figure of the notion sits between the method and the example, its description is in the HTML" do
    add_notion(revision_notion("Simplifier une racine carrée", figure: "triangle-thales"))

    open_course

    assert_select "section.sheet-section figure.sheet-figure[data-controller='figure']", count: 1
    assert_select "figure.sheet-figure figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    order = css_select("section.sheet-section > *").map { it["data-tone"] || it.name }
    assert_equal %w[h4 remember method figure div pitfall], order.map { it == "pitfall" ? "pitfall" : it }
  end

  test "the text of a notion is escaped: no HTML from the file reaches the page, no glossary" do
    notion = revision_notion("Piège").merge("pitfall" => "<script>alert(1)</script> et [[cle|mot]] **gras**")
    add_notion(notion)

    open_course

    assert_select ".sheet-box[data-tone='pitfall'] script", count: 0
    assert_select ".sheet-box[data-tone='pitfall'] b", text: "gras"
    assert_select "button.sheet-word", count: 0
    assert_includes response.body, "&lt;script&gt;"
  end

  test "CA-12: a long sheet is cut at the end of the block that reaches 150 words, all of it is in the HTML" do
    add_notion(revision_notion("Longue").merge("remember" => words(160)))
    add_notion(revision_notion("Seconde"))

    open_course

    assert_select ".sheet-box[data-tone='remember']#{REST}", count: 0
    assert_select "#{REST}.sheet-box[data-tone='method']", count: 1
    assert_select "#{REST}.sheet-card", count: 1
    assert_select "#{REST}.sheet-box[data-tone='pitfall']", count: 1
    assert_select "section.sheet-section#{REST}", count: 1, text: /Seconde/
    assert_select "[data-controller~='catalog--revision-more']" do
      assert_select "button[aria-expanded='false'][data-action='catalog--revision-more#toggle']", text: t("revision_more")
      assert_select "[data-catalog--revision-more-target='fade']"
      assert_select "p.sr-only[aria-live='polite'][data-catalog--revision-more-target='status']"
    end
    assert_no_match(/\shidden[\s>=]/, css_select("section.sheet-section").map(&:to_s).join)
  end

  test "CA-12: a short sheet is whole, with no « Voir plus »" do
    add_notion(revision_notion("Courte"))

    open_course

    assert_select REST, count: 0
    assert_select "[data-catalog--revision-more-target='button']", count: 0
    assert_select "[data-controller~='catalog--revision-more']", count: 0
  end

  test "a lesson without any notion sheet (old content) says the sheet is coming" do
    create_essential(course: @course, name: "Ancienne")

    open_course

    assert_select "section#fiche-de-revision", text: /#{Regexp.escape(t("revision_empty"))}/
    assert_select ".sheet-screen", count: 0
    assert_select "[data-catalog--revision-more-target='button']", count: 0
  end

  test "an unpublished notion is not shown to the student" do
    add_notion(revision_notion("Visible"))
    add_notion(revision_notion("Cachée"), status: "draft")

    open_course

    assert_select "h4.sheet-h2", count: 1, text: /Visible/
    assert_no_match(/Cachée/, response.body)
  end

  test "CA-14: a draft lesson answers 404 to a student and to a teacher" do
    draft = create_course(name: "Brouillon", status: "draft", figures: [ revision_figure ])
    sheet = { "remember" => "r", "method" => %w[a b], "example" => { "statement" => "s", "steps" => %w[c d] }, "pitfall" => "p" }
    create_essential(course: draft, name: "N", sheet:)

    [ create_student_for(draft), create_teacher ].each do |user|
      sign_in_as user
      get course_path(draft.slug)

      assert_response :not_found
    end
  end
end
