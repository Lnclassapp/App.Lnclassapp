require "test_helper"

# CA-4, CA-5, CA-6, CA-12 — la fiche de cours d'une leçon, lue dans la section « Fiche de révision » de la page de la leçon : 3 pages, titres
# de sections numérotés, encadrés, texte échappé, lexique. Son ancienne adresse répond 301 vers cette section ; mêmes refus (404).
class Catalog::CourseSheetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Propriétés de Thalès")
    @sheet = create_course_sheet(course: @course, document: reading_course_sheet_document)
    @student = create_student_for(@course)
  end

  def sheet_path(course = @course) = course_sheet_path(course.slug)
  # Since ADR-0113 the sheet is read in the lesson page, section « Fiche de révision ».
  def lesson_path(course = @course) = course_path(course.slug)

  test "CA-12: the old address of the sheet answers 301 to the lesson, on the sheet" do
    sign_in_as @student

    get sheet_path

    assert_redirected_to course_path(@course.slug, anchor: "fiche-de-revision")
    assert_response :moved_permanently
  end

  test "CA-12: the team is redirected for a draft lesson too" do
    course = create_course(status: "draft")
    create_course_sheet(course:, document: reading_course_sheet_document)
    sign_in_as create_team_member

    get sheet_path(course)

    assert_redirected_to course_path(course.slug, anchor: "fiche-de-revision")
    assert_response :moved_permanently
  end

  test "CA-12: a draft lesson, another level, no sheet, an unknown lesson: 404 for the student, never a redirect" do
    draft = create_course(status: "draft")
    create_course_sheet(course: draft, document: reading_course_sheet_document)
    sign_in_as create_student_for(draft)
    get sheet_path(draft)
    assert_response :not_found

    sign_in_as create_student(classroom: create_classroom(level: create_level(name: "Tle")))
    get sheet_path
    assert_response :not_found

    sign_in_as create_student_for(bare = create_course)
    get sheet_path(bare)
    assert_response :not_found
    get course_sheet_path("inconnue")
    assert_response :not_found
  end

  test "the student reads the three pages under the theme of the sheet" do
    sign_in_as @student

    get lesson_path

    assert_response :success
    assert_select "link[href*='course_sheet']"
    assert_select ".sheet-screen[data-sheet-theme='blue']"
    assert_select "[data-screen-label]", count: 3
    assert_select "[data-screen-label='Page 1']"
    assert_select "[data-screen-label='Page 3']"
    assert_select "h3.sheet-h1", text: "La propriété de Thalès"
    assert_select "h3.sheet-h2", text: /1\.\s*L'énoncé/
    assert_select "h3.sheet-h2", text: /4\.\s*Exercices d'application/
    assert_select "h3.sheet-h2", text: /5\.\s*Je m'entraîne/
    assert_select ".sheet-box .sheet-box-label", text: "Propriété de Thalès"
    assert_select ".sheet-simple", text: /Le petit triangle AMN/
    assert_select "ol.sheet-steps li", count: 3
    assert_select "table.sheet-table th", text: "Triangle"
  end

  test "the page footer counts the pages" do
    sign_in_as @student

    get lesson_path

    assert_select ".sheet-page-footer", text: "1 / 3"
    assert_select ".sheet-page-footer", text: "3 / 3"
  end

  test "a glossary word is a button and the glossary is given to the bubble" do
    sign_in_as @student

    get lesson_path

    assert_select "[data-controller~='course-sheet--glossary'] button.sheet-word", text: "sécantes"
    assert_select "[data-course-sheet--glossary-glossary-value*='Sécantes']"
    assert_select "[data-course-sheet--glossary-target='bubble'][hidden]"
    assert_select ".sheet-toolbar button", text: I18n.t("catalog.course_sheets.glossary.button")
  end

  test "the simple explanations are on by default, with their toggle" do
    sign_in_as @student

    get lesson_path

    assert_select ".sheet-screen[data-simple='true']"
    assert_select "button[aria-pressed='true']", text: I18n.t("catalog.course_sheets.simple.label_on")
  end

  test "the teacher's text is escaped" do
    document = reading_course_sheet_document
    document["pages"][0]["sections"][0]["blocks"][0]["text"] = "<script>alert(1)</script> **gras**"
    Orm::CourseSheet.where(id: @sheet.id).update_all(document:) # un document hostile, hors du contrôle de l'import
    sign_in_as @student

    get lesson_path

    assert_response :success
    assert_select "script", text: /alert/, count: 0
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_select "b", text: "gras"
  end

  test "the lesson page no longer links to its sheet: the sheet is a section of the page itself (UDR page de la leçon §3.1)" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "a[href='#{sheet_path}']", count: 0
    assert_select "section#fiche-de-revision"

    other = create_course
    sign_in_as create_student_for(other)
    get course_path(other.slug)

    assert_select "a[href='#{sheet_path(other)}']", count: 0
  end

  test "the table is readable as cards on a phone: each cell carries the label of its column" do
    sign_in_as @student

    get lesson_path

    assert_select "table.sheet-table td[data-label]"
    assert_select "table.sheet-table td[data-label='Triangle']"
  end

  test "the exercises of a sheet are given their fields, buttons and interface texts" do
    exercise = { "type" => "exercise", "title" => "Exercice 4", "prompt" => "Calculer AN.",
                 "fields" => [
                   { "id" => "an", "input" => "numeric", "label" => "AN =", "answer" => 3.6 },
                   { "id" => "mot", "input" => "choice", "label" => "Connecteur", "options" => [ "car", "donc" ], "answer" => 0, "frozen" => true }
                 ],
                 "hint" => "Écris d'abord les rapports.", "correction" => "AN = 3,6 cm." }
    practice = { "type" => "practice", "kind" => "bank", "title" => "Je m'entraîne",
                 "bank" => [ { "prompt" => "Calculer 2 + 2.", "answer" => 4, "solution" => "2 + 2 = 4." } ] }
    Orm::CourseSheet.where(id: @sheet.id).update_all(document: { "pages" => [ { "sections" => [ { "title" => "Exercices", "blocks" => [ exercise, practice ] } ] } ], "glossary" => {} })
    sign_in_as @student

    get lesson_path

    assert_select ".sheet-card .sheet-card-title", text: "Exercice 4"
    assert_select "input.sheet-input[data-field-id=an][data-input=numeric][data-answer='3.6']"
    assert_select "[data-input=choice][data-field-id=mot][data-frozen=true] button", 2
    assert_select "button", text: I18n.t("catalog.course_sheets.exercise.check")
    assert_select "button[aria-expanded=false]", text: I18n.t("catalog.course_sheets.exercise.hint")
    assert_select "button[aria-expanded=false]", text: I18n.t("catalog.course_sheets.exercise.correction")
    assert_select "[hidden]", text: /Écris d'abord les rapports\./
    assert_select ".sheet-practice button", text: I18n.t("catalog.course_sheets.practice.check")
    assert_select ".sheet-practice", text: /#{Regexp.escape(I18n.t("catalog.course_sheets.practice.score", ok: 0, total: 0))}/
  end

  test "the Thalès sheet of the seeds renders its figure in the initial position, with exercises and generator" do
    course = create_course(name: "Propriétés de Thalès dans un triangle", level: create_level(name: "3ème"))
    create_course_sheet(course:, document: JSON.parse(Rails.root.join("db/seeds/data/course_sheets/thales.json").read))
    sign_in_as create_student_for(course)

    get lesson_path(course)

    figure = "[data-controller~='course-sheet--thales-figure']"
    assert_response :success
    assert_select figure, 1
    assert_select "#{figure}[data-course-sheet--thales-figure-a-x-value='70'][data-course-sheet--thales-figure-a-y-value='165']"
    assert_select "#{figure}[data-course-sheet--thales-figure-b-x-value='360'][data-course-sheet--thales-figure-b-y-value='55']"
    assert_select "#{figure}[data-course-sheet--thales-figure-c-x-value='345'][data-course-sheet--thales-figure-c-y-value='285']"
    assert_select "#{figure}[data-course-sheet--thales-figure-k-m-value='0.45'][data-course-sheet--thales-figure-k-n-value='0.45']"
    assert_select "#{figure} [data-role=config]", text: I18n.t("catalog.course_sheets.kinds.thales_figure.config_triangle")
    assert_select "#{figure} [data-role=status]", text: I18n.t("catalog.course_sheets.kinds.thales_figure.status_locked")
    assert_select "#{figure} [data-ratio]", count: 3
    assert_select "#{figure} [data-ratio]", text: "0,45", count: 3
    assert_equal [ "7,8", "7,5", "5,8" ], css_select("#{figure} [data-cell]").select { %w[AB AC BC].include?(it["data-cell"]) }.map { it.text.strip }
    assert_equal %w[A B C M N], css_select("#{figure} svg text").map { it.text.strip }
    assert_select "#{figure} circle[data-hit]", 5
    assert_select "#{figure} button", text: I18n.t("catalog.course_sheets.kinds.thales_figure.lock_free")
    assert_select "#{figure} button", text: I18n.t("catalog.course_sheets.figure.reset")
    assert_select "input[data-field-id=e4an]"
    assert_select "input[data-field-id=e4mn]"
    assert_select "section[data-controller~='course-sheet--practice']"
  end
end
