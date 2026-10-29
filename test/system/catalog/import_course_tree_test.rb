require "application_system_test_case"

# CA-1 à CA-3, ADR-0039, ADR-0116, UDR-0038: the team opens the lesson (v3) import, reads its help, uploads a mixed file and follows
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

  def lessons_document(count, **overrides)
    { "format" => "lnclass.course-tree", "version" => 3,
      "courses" => Array.new(count) { |index| revision_sheet_document("name" => "Leçon #{index + 1}", **overrides).fetch("courses").first } }
  end

  test "the help of the kind is shown, then a mixed file gives the exact report without a page reload" do
    document = lessons_document(8)
    document["courses"][3]["name"] = ""
    document["courses"][4]["material_name"] = "Astronomie"
    document["courses"][7] = document["courses"][1].deep_dup
    file = json_file(document.to_json)

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    assert_no_page_reload do
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#import-help-course_tree h3", text: "Format du fichier"
        assert_selector "#import-help-course_tree", text: "Tout arrive en brouillon"
        assert_selector "#import-help-course_tree", text: "version 3"
        assert_selector "#import-help-exercise-rule", text: "un exercice"
        assert_selector "#import-help-exercise-rule", text: "quatre problèmes"
        assert_selector "#import-help-retired-version", text: "retirées"
        assert_selector "#import-help-keys details[open] code", text: "notions"
        find("summary", text: "Notion").click
        assert_selector "#import-help-keys code", text: "remember"
        find("summary", text: "Proposition").click
        assert_selector "#import-help-keys code", text: "is_correct"
        find("summary", text: "Exercice").click
        assert_selector "#import-help-keys code", text: "statement"
        assert_no_selector "#import-help-keys code", text: "description"
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
        assert_selector "#import_counter_imported", text: "5"
        assert_selector "#import_counter_skipped", text: "1"
        assert_selector "#import_counter_errors", text: "2"
        assert_selector "#import_counter_total", text: "8"
        assert_selector "#import_errors li", count: 2
        assert_selector "#import_errors li", text: /\Acourses\[3\]\.name\s+Valeur non conforme au format attendu\.\z/
        assert_selector "#import_errors li", text: /\Acourses\[4\]\.material_name\s+Matière inconnue\.\z/
        assert_text "Fiches de révision créées : 10"
        assert_text "Exercices créés : 30"
        assert_text "Questions créées : 150"
        assert_text "Propositions créées : 300"
      end
    end
    assert_equal [ "Leçon 1", "Leçon 2", "Leçon 3", "Leçon 6", "Leçon 7" ], Orm::Course.order(:name).pluck(:name)
    assert_equal [ "draft" ], Orm::Course.distinct.pluck(:status)
  end

  # CA-2 : une leçon v3 entre en brouillon avec ses notions et ses exercices.
  test "CA-2 a v3 lesson imports 1 lesson, its notions and its exercises" do
    file = json_file(revision_sheet_document.to_json)

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    within "turbo-frame#modal dialog[open]" do
      attach_file "import[files][]", file.path
      click_on "Lancer l'import"
    end

    using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
    within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
      assert_text "Terminé"
      assert_selector "#import_counter_imported", text: "1"
      assert_selector "#import_counter_errors", text: "0"
      assert_text "Fiches de révision créées : 2"
      assert_text "Exercices créés : 6"
    end
    assert_equal 6, Orm::Exercise.count
  end

  # CA-3 : une notion sans exercice refuse la leçon avec la raison de l'import (`essential_exercise_count`, CA-18), la notion
  # nommée par son chemin ; rien n'est écrit.
  test "CA-3 a notion without exercise: the report names the notion by its path, and nothing is written" do
    document = lessons_document(1)
    document["courses"][0]["notions"][1].delete("exercise")
    file = json_file(document.to_json)

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    within "turbo-frame#modal dialog[open]" do
      attach_file "import[files][]", file.path
      click_on "Lancer l'import"
    end

    using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
    within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
      assert_text "Terminé"
      assert_selector "#import_counter_imported", text: "0"
      assert_selector "#import_counter_errors", text: "1"
      assert_selector "#import_errors li", count: 1
      assert_selector "#import_errors li", text: /courses\[0\]\.notions\[1\].*il faut exactement un exercice par notion \(reçus : 0\)/m
    end
    assert_equal [ 0, 0 ], [ Orm::Course.count, Orm::Exercise.count ]
  end

  # CA-1 : un fichier du format retiré est refusé entier, avec sa raison.
  test "CA-1 a version 2 file is refused whole, with the retired format reason" do
    document = lessons_document(1).merge("version" => 2)
    file = json_file(document.to_json)

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    within "turbo-frame#modal dialog[open]" do
      attach_file "import[files][]", file.path
      click_on "Lancer l'import"
    end

    using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
    within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
      assert_text "Rejeté"
      assert_text "Ce format de fichier est retiré : utilisez la version 3"
    end
    assert_equal 0, Orm::Course.count
  end

  # IM-01, IM-11, IM-12 (ADR-0068, UDR-0055) : quatre leçons choisies d'un coup forment un seul import.
  test "IM-01 four lessons chosen at once: the summary, then one report with a line per file" do
    lessons = Array.new(4) do |index|
      document = lessons_document(1)
      document["courses"][0]["name"] = "Leçon fichier #{index + 1}"
      Rails.root.join("tmp/lecon-#{index + 1}.json").tap { |path| path.write(document.to_json) }.to_s
    end

    open_in_modal(new_teams_import_path(kind: "course_tree"))

    assert_no_page_reload do
      within "turbo-frame#modal dialog[open]" do
        attach_file "import[files][]", lessons
        assert_selector "#import_files_count", text: /\A4 fichiers · \d+ Ko\z/
        assert_selector "#import_files_list li", count: 4
        assert_selector "#import_files_list li:first-child", text: "lecon-1.json"
        assert_selector "#import_files_error", visible: :hidden
        click_on "Lancer l'import"
      end

      using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_selector "#import_counter_imported", text: "4"
        assert_selector "#import_counter_errors", text: "0"
        assert_selector "#import_files_title", text: "Fichiers (4)"
        assert_selector "#import_files li", text: /lecon-2\.json\s+1 importé · 0 ignoré · 0 en erreur/
      end
    end
    assert_selector "#imports tr", text: "lecon-1.json et 3 autres fichiers"
    assert_equal 4, Orm::Course.count
  ensure
    FileUtils.rm_f(Dir[Rails.root.join("tmp/lecon-*.json")])
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
