require "test_helper"

# DR-07, DR-10, UDR-0053: the DRENA import is the team's — its button sits before « Nouvelle DRENA », its modal shows the
# help of the format; a school staff member or a teacher can neither open it nor post a file of this kind.
class Teams::DrenaImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @member = create_team_member
  end

  def upload = Rack::Test::UploadedFile.new(Rails.root.join("db/seeds/data/imports/drenas-2026.json"), "application/json")

  def post_import(as: :turbo_stream)
    post teams_imports_path, params: { import: { kind: "drenas", io: upload } }, as:
  end

  test "DR-07 a school staff member and a teacher are refused the DRENA import, and no report is created" do
    [ create_user(role: "school_admin"), create_teacher ].each do |user|
      sign_in_as user

      get new_teams_import_path(kind: "drenas")
      assert_response :forbidden
      assert_no_difference -> { Orm::ImportReport.count } do
        assert_no_enqueued_jobs { post_import(as: nil) }
      end
      assert_response :forbidden
      sign_out
    end
  end

  test "DR-10 the DRENA screen shows « Importer des DRENA » before « Nouvelle DRENA », both opening the modal frame" do
    sign_in_as @member

    get drenas_path

    assert_response :success
    hrefs = [ new_teams_import_path(kind: "drenas"), new_drena_path ]
    buttons = css_select("a[data-turbo-frame=modal]").select { hrefs.include?(it["href"]) }
    assert_equal [ "Importer des DRENA", "Nouvelle DRENA" ], buttons.map { it.text.squish }
    assert_equal hrefs, buttons.pluck("href")
    assert_equal buttons.first.parent, buttons.last.parent
    assert_select "#drenas_empty", text: /Créez la première DRENA, ou importez-les toutes depuis un fichier JSON\./
  end

  test "DR-07 the team opens the modal of the DRENA kind, with the help of the format" do
    sign_in_as @member

    get new_teams_import_path(kind: "drenas"), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#import-upload-modal"
    assert_select "input[type=hidden][name='import[kind]'][value=drenas]"
    assert_select "#import_io_hint", text: /500 éléments au plus/
    assert_select "section#import-help-drenas[aria-labelledby=import-help-drenas-title]" do
      assert_select "h3#import-help-drenas-title", "Format du fichier"
      assert_select "dl > div", 1
      assert_select "dl dt code", "name"
      assert_select "pre code", text: /"format": "lnclass\.drenas",\s+"version": 1,\s+"drenas": \[\s+\{ "name": "Abidjan 1" \},\s+\{ "name": "Bouaké 1" \}/
      assert_select "svg[aria-hidden=true]", 1
      assert_select "code", text: "drena-bouake-1"
    end
  end

  test "DR-07 the team posts a DRENA file: the report is queued for the DRENA job" do
    sign_in_as @member

    assert_enqueued_with(job: School::ImportDrenasJob) { post_import }

    assert_response :success
    report = Orm::ImportReport.sole
    assert_equal [ "drenas", "queued", @member.id ], report.values_at(:kind, :status, :imported_by_id)
    assert_select "turbo-stream[action=update][target=modal] turbo-frame#import_status"
  end
end
