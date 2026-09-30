require "application_system_test_case"

# SC-08, SC-09, ADR-0039, UDR-0037: the team opens the schools import, reads its help, uploads a mixed file and follows
# it to its exact report, without a page reload. The real job runs as soon as it is enqueued.
class School::ImportSchoolsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  IMPORT_WAIT = 20

  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    queue_adapter.perform_enqueued_jobs = true
    seed_referential
    create_drena(name: "Abidjan 2")
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit teams_imports_path
  end

  def json_file(content)
    Tempfile.create([ "ecoles", ".json" ]).tap do |file|
      file.write(content)
      file.close
    end
  end

  test "the help of the kind is shown, then a mixed file gives the exact report without a page reload" do
    document = mixed(schools_document(count: 11, drena: "drena-abidjan-2"), invalid_at: [ 6 ], duplicate_of: { 9 => 1 })
    document["schools"][3]["schooltype"] = "semi-public"
    file = json_file(document.to_json)

    open_in_modal(new_teams_import_path(kind: "schools"))

    assert_no_page_reload do
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#import-help-schools h3", text: "Format du fichier"
        assert_selector "#import-help-schools", text: "Aucun établissement existant n'est modifié"
        assert_selector "#import-help-schools code", text: "schooltype"
        find("summary", text: "Slug de la DRENA (1)").click
        assert_selector "#import-help-drenas code", exact_text: "drena-abidjan-2"

        attach_file "import[files][]", file.path
        click_on "Lancer l'import"
      end

      # The request returns once the real job has written some 400 classrooms: seconds, on a loaded machine.
      using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_selector "#import_counter_imported", text: "8"
        assert_selector "#import_counter_skipped", text: "1"
        assert_selector "#import_counter_errors", text: "2"
        assert_selector "#import_counter_total", text: "11"
        assert_selector "#import_errors li", count: 2
        assert_selector "#import_errors li", text: /\Aschools\[3\]\.type\s+Valeur non valide\.\z/
        assert_selector "#import_errors li", text: /\Aschools\[6\]\.name\s+Valeur obligatoire manquante\.\z/
        assert_text "Classes générées : #{Orm::Classroom.count}"
        assert_no_text "Niveaux sautés"
      end
    end
    assert_equal 8, Orm::School.count
  end

  test "without any DRENA, the help says to create them first" do
    Orm::Drena.delete_all

    open_in_modal(new_teams_import_path(kind: "schools"))

    within "turbo-frame#modal dialog[open] #import-help-drenas" do
      assert_text "Aucune DRENA pour l'instant"
      assert_link "Ouvrir les DRENA", href: drenas_path
    end
  end
end
