require "application_system_test_case"

# ADR-0039, UDR-0006: a team member uploads a file in the modal and follows the import to its end, without a page
# reload. FakeImportJob is performed as soon as it is enqueued: the report is finished when the tracking appears.
class Teams::ImportFlowTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    # The server thread performs each job the moment it is enqueued, as the inline adapter would.
    queue_adapter.perform_enqueued_jobs = true
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit teams_imports_path
  end

  def json_file(content, name: "ecoles")
    Tempfile.create([ name, ".json" ]).tap do |file|
      file.write(content)
      file.close
    end
  end

  def upload(path)
    click_on "Nouvel import"
    within("#new-import-menu") { click_on "Établissements" }
    within "turbo-frame#modal dialog[open]" do
      attach_file "import[io]", path
      click_on "Lancer l'import"
    end
  end

  test "a mixed file ends « Terminé » with exact counts and every error at its JSON path" do
    file = json_file(mixed(schools_document(count: 10, drena: "drena-abidjan-2")).to_json)

    with_fake_import_job(existing: [ "Lycée Moderne 9" ]) do
      assert_no_page_reload do
        upload(file.path)

        assert_toast "Import lancé."
        within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
          assert_text "Terminé"
          assert_selector "#import_counter_imported", text: "6"
          assert_selector "#import_counter_skipped", text: "2"
          assert_selector "#import_counter_errors", text: "2"
          assert_selector "#import_counter_total", text: "10"
          assert_selector "#import_errors li", count: 2
          assert_selector "#import_errors li", text: /\Aschools\[3\]\.name\s+Valeur obligatoire manquante\.\z/
          assert_selector "#import_errors li", text: /\Aschools\[7\]\.name\s+Valeur obligatoire manquante\.\z/
        end
        assert_selector "#imports tr", text: File.basename(file.path)
      end
    end
  end

  test "a file whose envelope is wrong is « Rejeté », with its reason" do
    file = json_file(essentials_document(course: "svt", essentials: 1).to_json)

    with_fake_import_job do
      assert_no_page_reload do
        upload(file.path)

        within "turbo-frame#import_status" do
          assert_text "Rejeté"
          assert_selector "[role=alert]", text: "rejeté en bloc"
          assert_selector "#import_errors li", text: /\Aformat\s+Le format du fichier ne correspond pas/
        end
      end
    end
  end

  test "a file over 20 MB is refused in the modal (422)" do
    file = json_file("x" * (Entities::Catalog::ImportKind::MAX_BYTES + 1), name: "trop-gros")

    assert_no_page_reload do
      upload(file.path)

      within "turbo-frame#modal dialog[open]" do
        assert_selector "#import_io_error", text: "Fichier dépasse 20 Mo"
      end
    end
    assert_equal 0, Orm::ImportReport.count
  end

  test "the tracking frame reloads itself while the import runs, then stops" do
    report = create_import_report(status: "importing", processed_count: 100)
    visit teams_import_path(report.public_id)

    assert_no_page_reload do
      assert_text "Import en cours"
      report.update!(status: "completed", total_count: 3, imported_count: 3, finished_at: Time.current)

      using_wait_time(8) { assert_selector "turbo-frame#import_status", text: "Terminé" }
      assert_selector "#import_counter_imported", text: "3"
    end
  end
end
