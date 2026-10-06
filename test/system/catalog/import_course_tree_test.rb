require "application_system_test_case"

# CA-08, ADR-0039, UDR-0038: the team opens the course tree import, reads its help, uploads a mixed file and follows
# it to its exact report, without a page reload. The real job runs as soon as it is enqueued.
class Catalog::ImportCourseTreeTest < ApplicationSystemTestCase
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
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit teams_imports_path
  end

  def json_file(content)
    Tempfile.create([ "cours", ".json" ]).tap do |file|
      file.write(content)
      file.close
    end
  end

  test "the help of the kind is shown, then a mixed file gives the exact report without a page reload" do
    create_course(name: "Cours 6", level: Orm::Level.find_by!(slug: "tle"), material: Orm::Material.find_by!(slug: "svt"),
                  series: Orm::Series.find_by!(slug: "d"))
    document = mixed(course_tree_document(courses: 8, essentials: 1, exercises: 1, questions: 2, answers: 3),
                     invalid_at: [ 3 ], duplicate_of: { 7 => 1 })
    document["courses"][4]["material_name"] = "Astronomie"
    file = json_file(document.to_json)

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    assert_no_page_reload do
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#import-help-course_tree h3", text: "Format du fichier"
        assert_selector "#import-help-course_tree", text: "Tout arrive en brouillon"
        assert_selector "#import-help-keys details[open] code", text: "sous_titre"
        find("summary", text: "Proposition").click
        assert_selector "#import-help-keys code", text: "is_correct"
        find("summary", text: "Noms acceptés du référentiel").click
        assert_selector "#import-help-levels li", text: /Tle\s+A1 · A2 · C · D/
        assert_selector "#import-help-levels li", text: /6ème\s+sans série/
        assert_selector "#import-help-materials code", text: "Physique-Chimie"

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
        assert_selector "#import_errors li", text: /\Acourses\[3\]\.name\s+Valeur obligatoire manquante\.\z/
        assert_selector "#import_errors li", text: /\Acourses\[4\]\.material_name\s+Matière inconnue\.\z/
        assert_text "Fiches essentielles créées : 4"
        assert_text "Exercices créés : 4"
        assert_text "Questions créées : 8"
        assert_text "Propositions créées : 24"
      end
    end
    assert_equal [ "Cours 1", "Cours 2", "Cours 3", "Cours 6", "Cours 7" ], Orm::Course.order(:name).pluck(:name)
    assert_equal [ "draft" ], Orm::Course.where.not(name: "Cours 6").distinct.pluck(:status)
  end

  # IM-01, IM-11, IM-12 (ADR-0068, UDR-0055) : les 4 leçons de Tle D, choisies d'un coup, forment un seul import.
  test "IM-01 the four Tle D lessons chosen at once: the summary, then one report with a line per file" do
    lessons = %w[mathematiques/limites-et-continuite physique-chimie/cinematique-du-point physique-chimie/les-alcools
                 svt/le-devenir-des-cellules-sexuelles-chez-les-mammiferes]
              .map { Rails.root.join("docs/contenus/lecons-traitees/tle-d/#{it}.json").to_s }.sort_by { File.basename(it) }

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    assert_no_page_reload do
      within "turbo-frame#modal dialog[open]" do
        attach_file "import[files][]", lessons
        assert_selector "#import_files_count", text: /\A4 fichiers · \d+ Ko\z/
        assert_selector "#import_files_list li", count: 4
        assert_selector "#import_files_list li:first-child", text: "cinematique-du-point.json"
        assert_selector "#import_files_error", visible: :hidden
        click_on "Lancer l'import"
      end

      using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_selector "#import_counter_imported", text: "4"
        assert_selector "#import_counter_errors", text: "0"
        assert_text "Propositions créées : 786"
        assert_selector "#import_files_title", text: "Fichiers (4)"
        assert_selector "#import_files li", text: /limites-et-continuite\.json\s+1 importé · 0 ignoré · 0 en erreur/
      end
    end
    assert_selector "#imports tr", text: "cinematique-du-point.json et 3 autres fichiers"
    assert_equal 4, Orm::Course.count
  end

  # IM-11 : un dépassement se voit dès le choix, et l'envoi est désactivé.
  test "IM-11 choosing 51 files shows the limit at once and disables the import button" do
    dir = Dir.mktmpdir
    paths = Array.new(51) { |index| File.join(dir, "cours-#{index}.json").tap { File.write(it, "{}") } }

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    within "turbo-frame#modal dialog[open]" do
      attach_file "import[files][]", paths
      assert_selector "#import_files_error[role=alert]", text: "Vous avez choisi 51 fichiers : 50 au plus."
      assert_selector "input#import_files[aria-invalid=true]"
      assert_button "Lancer l'import", disabled: true

      attach_file "import[files][]", paths.first(2)
      assert_selector "#import_files_count", text: "2 fichiers · 1 Ko"
      assert_selector "#import_files_error", visible: :hidden
      assert_button "Lancer l'import", disabled: false
    end
  ensure
    FileUtils.rm_rf(dir)
  end

  test "with an empty referential, the help says to create it first" do
    Orm::ClassroomPlanEntry.delete_all
    Orm::LevelSeries.delete_all
    Orm::Level.delete_all

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    within "turbo-frame#modal dialog[open] #import-help-referential" do
      assert_text "Le référentiel est vide"
      assert_link "Ouvrir le référentiel", href: levels_path
    end
  end
end
