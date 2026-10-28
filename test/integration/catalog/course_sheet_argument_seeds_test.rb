require "test_helper"

# contenu-en-blocs (chantier 318), Lot F: the « Le texte argumentatif » sheet shipped with the seeds targets the slug the demo lesson gets,
# goes through the real import chain (schema, SheetDocument, repository), reads in the page of the lesson, and the demo seed picks it up.
class Catalog::CourseSheetArgumentSeedsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PATH = Rails.root.join("db/seeds/data/course_sheets/texte-argumentatif.json")
  LESSON = Rails.root.join("docs/contenus/lecons-traitees/3eme/francais/le-texte-argumentatif.json")

  setup do
    @course = create_course(name: "Le texte argumentatif", level: create_level(name: "3ème"))
    @document = JSON.parse(PATH.read)
  end

  def import(document)
    file = Rack::Test::UploadedFile.new(StringIO.new(document.to_json), "application/json", original_filename: "texte-argumentatif.json")
    perform_enqueued_jobs do
      post teams_imports_path, params: { import: { kind: "course_sheet", files: [ file ] } }, as: :turbo_stream
    end
    Orm::ImportReport.order(:id).last
  end

  test "the file targets the lesson of the lecons-traitees tree and its slug, and the import goes through" do
    assert_equal "Le texte argumentatif", JSON.parse(LESSON.read).dig("courses", 0, "name")
    assert_equal @course.slug, @document["course"]
    sign_in_as create_team_member(team_role: "content")

    report = import(@document)

    assert_equal [ "completed", 1, 0 ], [ report.status, report.imported_count, report.error_count ], report.inspect
    assert_equal "burgundy", Orm::CourseSheet.find_by!(course_id: @course.id).theme
  end

  test "the imported sheet reads in the lesson page: three pages, highlighter, seven connectors rows, seven exercises, generator, writing" do
    sign_in_as create_team_member(team_role: "content")
    import(@document)
    sign_out
    sign_in_as create_student_for(@course)

    get course_path(@course.slug)

    assert_response :success
    assert_select ".sheet-screen[data-sheet-theme=burgundy] [data-screen-label]", 3
    assert_select "h3.sheet-h1", text: "Le texte argumentatif"
    assert_select "[data-controller~='course-sheet--argument-highlighter'] .sheet-hl-seg[data-kind=thesis]", 2
    assert_select ".sheet-hl-btn", 5
    assert_select ".sheet-table tbody tr", 7
    assert_select ".sheet-card[data-controller~='course-sheet--exercise']", 7
    assert_select "[data-input=choice][data-frozen=true]", 4
    assert_select "section[data-controller~='course-sheet--practice'][data-course-sheet--practice-kind-value='bank']"
    assert_select "section[data-controller~='course-sheet--writing'] textarea", 1
    assert_select "button.sheet-word", minimum: 15
    assert_select "[style]", 0
  end

  test "every exercise answer points at an existing option, every bank answer at one of the three numbered propositions" do
    @document["pages"].flat_map { it["sections"] }.flat_map { it["blocks"] }.each do |block|
      Array(block["fields"]).each { |field| assert_operator field["answer"], :<, field["options"].size, field["id"] }
      next unless block["kind"] == "bank"

      block["bank"].each { |item| assert_includes 1..3, item["answer"].to_i, item["prompt"] }
    end
  end
end
