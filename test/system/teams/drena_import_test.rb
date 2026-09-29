require "application_system_test_case"

# DR-10, UDR-0041: on the DRENA screen, « Importer des DRENA » sits next to « Nouvelle DRENA » and opens the import modal
# with the help of the format; the delivered file gives « Terminé », 41 imported, and a second upload 41 skipped —
# without a page reload. The real job runs as soon as it is enqueued.
class Teams::DrenaImportTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  IMPORT_WAIT = 20
  DELIVERED = Rails.root.join("db/seeds/data/imports/drenas-2026.json").to_s

  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    queue_adapter.perform_enqueued_jobs = true
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit drenas_path
  end

  def upload_delivered_file
    within "turbo-frame#modal dialog[open]" do
      attach_file "import[io]", DELIVERED
      click_on "Lancer l'import"
    end
    using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
  end

  test "the import button opens the modal with its help; the delivered file gives 41 imported, then 41 skipped" do
    assert_selector "#drenas_empty", text: "Créez la première DRENA, ou importez-les toutes depuis un fichier JSON."
    assert_link "Importer des DRENA", href: new_teams_import_path(kind: "drenas")
    assert_link "Nouvelle DRENA", href: new_drena_path

    assert_no_page_reload do
      click_on "Importer des DRENA"

      within "turbo-frame#modal dialog[open]" do
        assert_selector "h2", text: "Importer : DRENA"
        assert_selector "#import-help-drenas h3", text: "Format du fichier"
        assert_selector "#import-help-drenas dt code", text: "name"
        assert_selector "#import-help-drenas code", text: "drena-bouake-1"
      end
      upload_delivered_file

      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_selector "#import_counter_imported", text: "41"
        assert_selector "#import_counter_skipped", text: "0"
        assert_selector "#import_counter_errors", text: "0"
        assert_selector "#import_counter_total", text: "41"
      end
    end
    assert_equal 41, Orm::Drena.count

    open_in_modal(new_teams_import_path(kind: "drenas"))
    upload_delivered_file

    within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
      assert_text "Terminé"
      assert_selector "#import_counter_imported", text: "0"
      assert_selector "#import_counter_skipped", text: "41"
    end
    assert_equal 41, Orm::Drena.count

    visit drenas_path
    assert_selector "#drenas tr", count: 41
    assert_selector "#drenas tr", text: /Bouaké 1\s+drena-bouake-1/
  end
end
