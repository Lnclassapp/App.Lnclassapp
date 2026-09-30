require "application_system_test_case"

# AS-06 replaced, TR-28, ADR-0039, UDR-0040: the team opens the exercises import of an essential, reads its help,
# uploads a mixed file and follows it to its exact report, without a page reload. The real job runs as soon as it is enqueued.
class Assessment::ImportExercisesTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  IMPORT_WAIT = 20

  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    queue_adapter.perform_enqueued_jobs = true
    @essential = create_essential(name: "Brassage génétique", status: "draft")
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit teams_imports_path
  end

  def json_file(content)
    Tempfile.create([ "exercices", ".json" ]).tap do |file|
      file.write(content)
      file.close
    end
  end

  test "the help names the target essential, then a mixed file gives the exact report without a page reload" do
    create_exercise(essential: @essential, title: "Exercice 7", questions: 0)
    document = mixed(exercises_document(essential: @essential.slug, exercises: 8, questions: 2, answers: 3),
                     invalid_at: [ 3 ], duplicate_of: { 5 => 1 })
    document["exercises"][4]["questions"][1]["question_type"] = "true_false"
    file = json_file(document.to_json)

    open_in_modal(new_teams_import_path(kind: "exercises", essential: @essential.slug))

    assert_no_page_reload do
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#import-help-exercises h3", text: "Format du fichier"
        assert_selector "#import-help-essential code", exact_text: @essential.slug
        assert_selector "#import-help-example", text: %("essential": "#{@essential.slug}")
        assert_selector "#import-help-exercises", text: "Tout arrive en brouillon"
        assert_selector "#import-help-keys details[open] code", text: "name"
        find("summary", text: "Proposition").click
        assert_selector "#import-help-keys code", text: "is_correct"

        attach_file "import[files][]", file.path
        click_on "Lancer l'import"
      end

      using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_selector "#import_counter_imported", text: "4"
        assert_selector "#import_counter_skipped", text: "2"
        assert_selector "#import_counter_errors", text: "2"
        assert_selector "#import_counter_total", text: "8"
        assert_selector "#import_errors li", count: 2
        assert_selector "#import_errors li", text: /\Aexercises\[3\]\.title\s+Valeur obligatoire manquante\.\z/
        assert_selector "#import_errors li", text: /\Aexercises\[4\]\.questions\[1\]\.answers\s+Question incomplète/
        assert_text "Questions créées : 8"
        assert_text "Propositions créées : 24"
      end
    end
    assert_equal [ "Exercice 7", "Exercice 1", "Exercice 2", "Exercice 3", "Exercice 8" ],
                 @essential.exercises.order(:position).pluck(:title)
    assert_equal [ "draft" ], @essential.exercises.where.not(title: "Exercice 7").distinct.pluck(:status)
  end

  test "without a target, the help says where to cite the essential" do
    open_in_modal(new_teams_import_path(kind: "exercises"))

    within "turbo-frame#modal dialog[open] #import-help-essential" do
      assert_text "citez son slug dans la clé essential de l'enveloppe"
    end
    assert_selector "#import-help-example", text: %("essential": "genetique-et-evolution-brassage-genetique")
  end
end
