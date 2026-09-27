require "test_helper"

# ADR-0039, UDR-0006: the imports screen of the team — list, upload in the modal frame, tracking frame.
class Teams::ImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @member = create_team_member
  end

  def upload(content = schools_document(count: 2, drena: "abidjan-2").to_json, filename: "ecoles.json")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/json", original_filename: filename)
  end

  def post_import(io: upload, kind: "schools", as: :turbo_stream)
    post teams_imports_path, params: { import: { kind:, io: } }, as:
  end

  test "a teacher receives 403 on every action" do
    sign_in_as create_teacher

    get teams_imports_path
    assert_response :forbidden
    get new_teams_import_path(kind: "schools")
    assert_response :forbidden
    post_import(as: nil)
    assert_response :forbidden
  end

  test "the list shows recent reports, and filters them by kind" do
    create_import_report(kind: "schools", status: "completed", imported_count: 12, total_count: 12)
    create_import_report(kind: "exercises", status: "rejected")
    sign_in_as @member

    get teams_imports_path

    assert_response :success
    assert_select "nav a[href='#{teams_imports_path}'][aria-current=page]", text: "Imports"
    assert_select "#imports tr", 2
    assert_select "#imports", text: /Terminé/
    assert_select "#imports", text: /Rejeté/
    assert_select "a[data-turbo-frame=modal][href='#{new_teams_import_path(kind: 'course_tree')}']"

    get teams_imports_path(kind: "exercises")

    assert_select "#imports tr", 1
    assert_select "#imports", text: /Exercices/
    assert_select "nav a[aria-current=page]", text: "Exercices"
  end

  test "an empty list says so" do
    sign_in_as @member

    get teams_imports_path(kind: "unknown")

    assert_select "#imports tr", 0
    assert_select "#imports_empty", text: /Aucun import/
  end

  test "the upload form opens in the modal frame, with the limits of its kind" do
    sign_in_as @member

    get new_teams_import_path(kind: "schools"), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal", 1
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#import-upload-modal"
    assert_select "input[type=file][name='import[io]'][accept='.json,application/json']"
    assert_select "input[type=hidden][name='import[kind]'][value=schools]"
    assert_select "#import_io_hint", text: /20 Mo au plus, avec 5 000 éléments au plus/
  end

  test "an unknown kind has no upload form" do
    sign_in_as @member

    get new_teams_import_path(kind: "unknown")
    assert_response :not_found
    post_import(kind: "unknown", as: nil)
    assert_response :not_found
  end

  test "a file over 20 MB is refused in the modal, and nothing is created" do
    sign_in_as @member

    assert_no_difference -> { Orm::ImportReport.count } do
      post_import(io: upload("x" * (Entities::Catalog::ImportKind::MAX_BYTES + 1)), as: nil)
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal #import_io_error", text: "Fichier dépasse 20 Mo"
    assert_select "input[type=file][aria-invalid=true]"
  end

  test "a file that is not JSON, or no file at all, is refused" do
    sign_in_as @member

    post_import(io: upload(filename: "ecoles.csv"), as: nil)
    assert_response :unprocessable_entity
    assert_select "#import_io_error", text: "Nom du fichier doit se terminer par .json"

    post_import(io: "pas un fichier", as: nil)
    assert_response :unprocessable_entity
    assert_select "#import_io_error", text: /Fichier doit être rempli/
  end

  test "a second import of the same kind while one runs is refused with its reason" do
    create_import_report(kind: "schools", status: "queued")
    sign_in_as @member

    with_fake_import_job { post_import(as: nil) }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal [role=alert]", text: "Un import de ce type est déjà en cours."
  end

  test "an accepted file answers in Turbo Stream: toast, tracking in the modal, row on top of the list" do
    sign_in_as @member

    with_fake_import_job do
      assert_enqueued_with(job: FakeImportJob) { post_import }
    end

    report = Orm::ImportReport.sole
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: /Import lancé/
    assert_select "turbo-stream[action=update][target=modal] turbo-frame#import_status[data-controller='teams--import-status']"
    assert_select "turbo-stream[action=update][target=modal] [data-status=queued]"
    assert_select "turbo-stream[action=prepend][target=imports] tr#import_#{report.public_id}", text: /ecoles\.json/
    assert_equal @member.id, report.imported_by_id
  end

  test "without Turbo, an accepted file leads to its tracking page" do
    sign_in_as @member

    with_fake_import_job { post_import(as: nil) }

    assert_redirected_to teams_import_path(Orm::ImportReport.sole.public_id)
  end

  test "the tracking page shows a finished report, its counts, details and errors" do
    report = create_import_report(status: "completed", total_count: 4, imported_count: 1, skipped_count: 1, error_count: 2,
                                  details: { "classrooms" => 77, "levels_skipped" => 2 }, finished_at: Time.current,
                                  import_errors: [ { "path" => "schools[3].name", "code" => "blank", "params" => {} },
                                                   { "path" => "schools[4]", "code" => "schema", "params" => { "keyword" => "required" } } ])
    sign_in_as @member

    get teams_import_path(report.public_id)

    assert_response :success
    assert_select "h1", "Import : Établissements"
    assert_select "nav a[href='#{teams_imports_path}'][aria-current=page]", text: "Imports"
    assert_select "#import_counter_imported", "1"
    assert_select "#import_counter_total", "4"
    assert_select "li", text: /Classes générées : 77/
    assert_select "li", text: /Levels skipped : 2/
    assert_select "#import_errors li", 2
    assert_select "#import_errors li", text: /schools\[4\]\s*Valeur non conforme au format attendu \(required\)/
  end

  test "the tracking frame alone answers a request coming from the frame" do
    report = create_import_report(status: "importing", processed_count: 200)
    sign_in_as @member

    get teams_import_path(report.public_id), headers: { "Turbo-Frame" => "import_status" }

    assert_response :success
    assert_no_match "<html", response.body
    assert_select "turbo-frame#import_status[data-teams--import-status-url-value='#{teams_import_path(report.public_id)}'] [data-status=importing]"
    assert_select "progress"
    assert_match "200 éléments vérifiés", response.body
  end

  test "a rejected report shows its reason; a failed one says it stopped" do
    rejected = create_import_report(status: "rejected", finished_at: Time.current,
                                    import_errors: [ { "path" => "format", "code" => "format_mismatch",
                                                       "params" => { "expected" => "lnclass.schools" } } ])
    failed = create_import_report(kind: "exercises", status: "failed", finished_at: Time.current)
    sign_in_as @member

    get teams_import_path(rejected.public_id)
    assert_select "[role=alert]", text: /rejeté en bloc/
    assert_select "#import_errors li", text: /attendu : lnclass\.schools/

    get teams_import_path(failed.public_id)
    assert_select "[role=alert]", text: /erreur imprévue/
  end

  test "beyond 1 000 errors, the rest is announced" do
    errors = Array.new(Entities::Catalog::ImportKind::MAX_ERRORS) { { "path" => "schools[#{it}].name", "code" => "blank", "params" => {} } }
    report = create_import_report(status: "completed", error_count: 1_001, total_count: 1_001, import_errors: errors,
                                  finished_at: Time.current)
    sign_in_as @member

    get teams_import_path(report.public_id)

    assert_select "#import_errors li", 1_000
    assert_match "Et 1 autre élément en erreur, non détaillé.", response.body
  end

  test "an unknown report is not found" do
    sign_in_as @member

    get teams_import_path("inconnu")

    assert_response :not_found
  end
end
