require "test_helper"

# CA-1, CA-2, CA-4 (import): the team imports a course sheet file from the imports screen, the job runs, the report tells.
class Catalog::CourseSheetImportTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @course = create_course(name: "La propriété de Thalès")
  end

  def file(document) = Rack::Test::UploadedFile.new(StringIO.new(document.to_json), "application/json", original_filename: "thales.json")

  def document(**overrides)
    { "format" => "lnclass.course-sheet", "version" => 1, "course" => @course.slug, "theme" => "blue", **course_sheet_document, **overrides }
  end

  def import(document)
    perform_enqueued_jobs do
      post teams_imports_path, params: { import: { kind: "course_sheet", files: [ file(document) ] } }, as: :turbo_stream
    end
  end

  test "the screen lists the kind, a content member imports a sheet, the report counts 1 imported" do
    sign_in_as create_team_member(team_role: "content")

    get teams_imports_path
    assert_select "#new-import-menu a[href='#{new_teams_import_path(kind: 'course_sheet')}']", text: "Contenu de fiche de cours"
    get new_teams_import_path(kind: "course_sheet")
    assert_response :success

    import(document)

    assert_response :success
    report = Orm::ImportReport.order(:id).last
    assert_equal [ "course_sheet", "completed", 1, 0 ], [ report.kind, report.status, report.imported_count, report.error_count ]
    assert_equal "blue", Orm::CourseSheet.find_by!(course_id: @course.id).theme
    get teams_import_path(report)
    assert_response :success
  end

  test "a hostile file is refused with a report line per block, nothing is written" do
    sign_in_as create_team_member(team_role: "content")
    hostile = document
    hostile["pages"][0]["sections"][0]["blocks"][0] = { "type" => "paragraph", "text" => "<img src=x onerror=alert(1)>" }

    import(hostile)

    report = Orm::ImportReport.order(:id).last
    assert_equal [ 0, "rejected" ], [ Orm::CourseSheet.count, report.status ]
    get teams_import_path(report)
    assert_select "#import_errors code", text: "pages[0].sections[0].blocks[0].text"
  end

  test "a teacher and a student are refused the course sheet import, no report is written" do
    [ create_teacher, create_student ].each do |user|
      sign_in_as user

      assert_no_difference "Orm::ImportReport.count" do
        post teams_imports_path, params: { import: { kind: "course_sheet", files: [ file(document) ] } }, as: :turbo_stream
      end
      assert_response :forbidden
      sign_out
    end
    assert_equal 0, Orm::CourseSheet.count
  end

  test "a teacher cannot reach the import" do
    sign_in_as create_teacher

    get new_teams_import_path(kind: "course_sheet")

    assert_response :forbidden
  end
end
