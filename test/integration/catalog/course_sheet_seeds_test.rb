require "test_helper"

# contenu-en-blocs (chantier 318), Lot D: the Thalès sheet shipped with the seeds goes through the real import chain
# (schema, SheetDocument, repository) and the imported sheet is readable by a student.
class Catalog::CourseSheetSeedsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PATH = Rails.root.join("db/seeds/data/course_sheets/thales.json")
  LESSON = "Propriétés de Thalès dans un triangle".freeze

  setup do
    @course = create_course(name: LESSON, level: create_level(name: "3ème"))
    @document = JSON.parse(PATH.read)
  end

  def import(document)
    file = Rack::Test::UploadedFile.new(StringIO.new(document.to_json), "application/json", original_filename: "thales.json")
    perform_enqueued_jobs do
      post teams_imports_path, params: { import: { kind: "course_sheet", files: [ file ] } }, as: :turbo_stream
    end
    Orm::ImportReport.order(:id).last
  end

  test "the file targets the slug the lesson of the demo gets, and the seeds import it for real" do
    assert_equal @course.slug, @document["course"]
    sign_in_as create_team_member(team_role: "content")

    report = import(@document)

    assert_equal [ "completed", 1, 0 ], [ report.status, report.imported_count, report.error_count ], report.inspect
    assert_equal "blue", Orm::CourseSheet.find_by!(course_id: @course.id).theme
  end

  test "the imported sheet reads: three pages, the figure, seven exercises and the generator" do
    sign_in_as create_team_member(team_role: "content")
    import(@document)
    sign_out
    sign_in_as create_student_for(@course)

    get course_sheet_path(@course.slug)

    assert_response :success
    assert_select "[data-screen-label]", 3
    assert_select "h1", text: "La propriété de Thalès"
    assert_select "[data-controller~='course-sheet--thales-figure'] svg"
    assert_select ".sheet-card[data-controller~='course-sheet--exercise']", 7
    assert_select "section[data-controller~='course-sheet--practice'][data-course-sheet--practice-kind-value='thales_ratio']"
    assert_select "button.sheet-word", minimum: 15
    assert_select ".sheet-screen[data-course-sheet--glossary-glossary-value*='Réciproque']"
  end

  # La seed de la fiche, jouée comme dans un environnement de PR (garde-fou levé par les variables de Railway).
  PR_VARIABLES = { "PR_BASE_ENVIRONMENT" => "Develop", "RAILWAY_ENVIRONMENT_NAME" => "lnclass-pr-318" }.freeze

  def run_seed
    previous = PR_VARIABLES.keys.to_h { [ it, ENV[it] ] }
    PR_VARIABLES.each { |key, value| ENV[key] = value }
    capture_io { load Rails.root.join("db/seeds/demo/fiches_de_cours.rb").to_s, true }.first
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  test "the demo seed imports the sheet on the lesson, then a second run does nothing" do
    create_team_member(team_role: "content", second_factor: false, contact: "0700000000")

    assert_includes run_seed, "1 fiche(s) de cours importée(s) sur 2"
    assert_equal [ @course.id ], Orm::CourseSheet.pluck(:course_id)
    sheet = Orm::CourseSheet.last

    assert_includes run_seed, "0 fiche(s) de cours importée(s) sur 2"
    assert_equal [ 1, sheet.updated_at ], [ Orm::CourseSheet.count, Orm::CourseSheet.last.updated_at ]
  end

  test "the demo seed says so, and does not fail, when the lesson is missing" do
    create_team_member(team_role: "content", second_factor: false, contact: "0700000000")
    @course.destroy!

    output = run_seed

    assert_includes output, "leçon « proprietes-de-thales-dans-un-triangle » absente"
    assert_equal 0, Orm::CourseSheet.count
  end

  test "the seed refuses to run outside development and the PR environments" do
    error = assert_raises(RuntimeError) { load Rails.root.join("db/seeds/demo/fiches_de_cours.rb").to_s, true }

    assert_match(/réservé au développement/, error.message)
  end
end
