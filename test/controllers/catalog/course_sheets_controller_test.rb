require "test_helper"

# CA-4, CA-5, CA-6 — la fiche de cours d'une leçon. L'élève de son niveau lit une leçon publiée : 3 pages, titres de sections
# numérotés, encadrés, texte échappé, lexique. Une leçon en brouillon, un autre niveau ou une leçon sans fiche : 404.
class Catalog::CourseSheetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Propriétés de Thalès")
    @sheet = create_course_sheet(course: @course, document: reading_course_sheet_document)
    @student = create_student_for(@course)
  end

  def sheet_path(course = @course) = course_sheet_path(course.slug)

  test "the student reads the three pages under the theme of the sheet" do
    sign_in_as @student

    get sheet_path

    assert_response :success
    assert_select "link[href*='course_sheet']"
    assert_select ".sheet-screen[data-sheet-theme='blue']"
    assert_select "[data-screen-label]", count: 3
    assert_select "[data-screen-label='Page 1']"
    assert_select "[data-screen-label='Page 3']"
    assert_select "h1", text: "La propriété de Thalès"
    assert_select "h2", text: /1\.\s*L'énoncé/
    assert_select "h2", text: /4\.\s*Exercices d'application/
    assert_select "h2", text: /5\.\s*Je m'entraîne/
    assert_select ".sheet-box .sheet-box-label", text: "Propriété de Thalès"
    assert_select ".sheet-simple", text: /Le petit triangle AMN/
    assert_select "ol.sheet-steps li", count: 3
    assert_select "table.sheet-table th", text: "Triangle"
  end

  test "the page footer counts the pages" do
    sign_in_as @student

    get sheet_path

    assert_select ".sheet-page-footer", text: "1 / 3"
    assert_select ".sheet-page-footer", text: "3 / 3"
  end

  test "a glossary word is a button and the glossary is given to the bubble" do
    sign_in_as @student

    get sheet_path

    assert_select "[data-controller~='course-sheet--glossary'] button.sheet-word", text: "sécantes"
    assert_select "[data-course-sheet--glossary-glossary-value*='Sécantes']"
    assert_select "[data-course-sheet--glossary-target='bubble'][hidden]"
    assert_select ".sheet-toolbar button", text: I18n.t("catalog.course_sheets.glossary.button")
  end

  test "the simple explanations are on by default, with their toggle" do
    sign_in_as @student

    get sheet_path

    assert_select ".sheet-screen[data-simple='true']"
    assert_select "button[aria-pressed='true']", text: I18n.t("catalog.course_sheets.simple.label_on")
  end

  test "the teacher's text is escaped" do
    document = reading_course_sheet_document
    document["pages"][0]["sections"][0]["blocks"][0]["text"] = "<script>alert(1)</script> **gras**"
    Orm::CourseSheet.where(id: @sheet.id).update_all(document:) # un document hostile, hors du contrôle de l'import
    sign_in_as @student

    get sheet_path

    assert_response :success
    assert_select "script", text: /alert/, count: 0
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_select "b", text: "gras"
  end

  test "CA-4: a draft lesson is refused to the student" do
    course = create_course(status: "draft")
    create_course_sheet(course:, document: reading_course_sheet_document)
    sign_in_as create_student_for(course)

    get sheet_path(course)

    assert_response :not_found
  end

  test "a student of another level does not read it" do
    sign_in_as create_student(classroom: create_classroom(level: create_level(name: "Tle")))

    get sheet_path

    assert_response :not_found
  end

  test "a lesson without a sheet answers 404" do
    sign_in_as create_student_for(course = create_course)

    get sheet_path(course)

    assert_response :not_found
  end

  test "an unknown lesson answers 404" do
    sign_in_as @student

    get course_sheet_path("inconnue")

    assert_response :not_found
  end

  test "the team reads the sheet of a draft lesson" do
    course = create_course(status: "draft")
    create_course_sheet(course:, document: reading_course_sheet_document)
    sign_in_as create_team_member

    get sheet_path(course)

    assert_response :success
  end

  test "the lesson page links to its sheet, and only when it has one" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "a[href='#{sheet_path}']", text: I18n.t("catalog.course_sheets.name")

    other = create_course
    sign_in_as create_student_for(other)
    get course_path(other.slug)

    assert_select "a[href='#{sheet_path(other)}']", count: 0
  end
end
