require "application_system_test_case"

# CA-15, ADR-0039, UDR-0039: from the page of a course, the team opens the essentials import with the course slug,
# reads its help, uploads a mixed file and follows it to its exact report, without a page reload. The real job runs as
# soon as it is enqueued.
class Catalog::ImportEssentialsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  IMPORT_WAIT = 20

  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true, formats: :html) })
  end

  setup do
    queue_adapter.perform_enqueued_jobs = true
    sign_in_as create_team_member
    assert_current_path team_home_path
    @course = create_course(name: "Génétique et Évolution")
    create_essential(course: @course, name: "Fiche 6")
  end

  def json_file(content)
    Tempfile.create([ "fiches", ".json" ]).tap do |file|
      file.write(content)
      file.close
    end
  end

  test "the course slug is recalled, then a mixed file gives the exact report without a page reload" do
    document = mixed(essentials_document(course: @course.slug, essentials: 8, exercises: 1, questions: 2, answers: 3),
                     invalid_at: [ 3 ], duplicate_of: { 7 => 1 })
    document["essentials"][4]["exercises"][0]["exercise_type"] = "quiz"
    file = json_file(document.to_json)

    visit course_path(@course.slug)

    assert_no_page_reload do
      find("button[aria-controls='course-actions-menu']").click
      click_on "Importer des fiches essentielles"
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#import-help-essentials h3", text: "Format du fichier"
        assert_selector "#import-help-course code", text: @course.slug
        assert_selector "#import-help-example", text: %("course": "#{@course.slug}")
        assert_selector "#import-help-essentials", text: "Tout arrive en brouillon, à la suite des fiches essentielles du cours"
        assert_selector "#import-help-keys details[open] code", text: "subtitle"
        find("summary", text: "Exercice").click
        assert_selector "#import-help-keys code", text: "exercise_type"

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
        assert_selector "#import_errors li", text: /\Aessentials\[3\]\.name\s+Valeur obligatoire manquante\.\z/
        assert_selector "#import_errors li", text: /\Aessentials\[4\]\.exercises\[0\]\.exercise_type\s+Valeur non valide\.\z/
        assert_text "Exercices créés : 4"
        assert_text "Questions créées : 8"
        assert_text "Propositions créées : 24"
      end
    end
    assert_equal [ [ "Fiche 6", 1 ], [ "Fiche 1", 2 ], [ "Fiche 2", 3 ], [ "Fiche 3", 4 ], [ "Fiche 7", 5 ] ],
                 @course.essentials.order(:position).pluck(:name, :position)
    assert_equal [ "draft" ], @course.essentials.where.not(name: "Fiche 6").distinct.pluck(:status)
  end

  test "opened without a course, the help says where to read its slug" do
    visit teams_imports_path
    open_in_modal(new_teams_import_path(kind: "essentials"))

    within "turbo-frame#modal dialog[open] #import-help-course" do
      assert_text "Citez le cours cible par son slug"
      assert_no_selector "input[name='course']", visible: :all
    end
    assert_selector "#import-help-example", text: %("course": "genetique-et-evolution")
  end
end
