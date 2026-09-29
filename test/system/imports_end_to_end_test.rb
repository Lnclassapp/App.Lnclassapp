require "application_system_test_case"

# Lot E, ADR-0039, UDR-0006: the team imports through the real buttons, from its own screens, and follows each report to
# its end without a page reload. Files come from the real samples of the former application (enveloped), kept to a few
# elements: volume belongs to the performance tests. The real job runs as soon as it is enqueued.
class ImportsEndToEndTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  IMPORT_WAIT = 20
  PUBLIC_SCHOOL = "Lycée Classique d'Abidjan"
  PRIVATE_SCHOOL = "Lycée Blaise Pascal"
  COURSE = "Génétique et Évolution"
  ESSENTIAL = "Brassage génétique par la méiose"

  setup do
    queue_adapter.perform_enqueued_jobs = true
    # Only Tle, D and SVT, with the barème taken over as at the deployment (ADR-0058): a public lycée gets « Tle D 1 » to
    # « Tle D 6 », a private one three; nothing else is in the referential, so nothing is skipped.
    tle = create_level(name: "Tle", position: 7, cycle: "second")
    link_level_series(level: tle, series: create_series(name: "D"))
    seed_classroom_plan
    create_material(name: "SVT", shortname: "SVT", category: "science")
    create_drena(name: "Abidjan 2")
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def json_file(document, name:)
    Tempfile.create([ name, ".json" ]).tap do |file|
      file.write(document.to_json)
      file.close
    end
  end

  # The legacy sample, enveloped, cut down to the named schools, in that order.
  def legacy_schools(*names)
    document = import_sample("schools_legacy_sample")
    document["schools"] = names.map { |name| document["schools"].find { it["name"] == name }.deep_dup }
    document
  end

  # The legacy sample cut down to one course, one essential, one exercise of two true/false questions.
  def legacy_course_tree
    document = import_sample("course_tree_tle_d_sample")
    course = document["courses"].first
    essential = course["essentials"].first
    exercise = essential["exercises"].first
    exercise["questions"] = exercise["questions"].first(2)
    essential["exercises"] = [ exercise ]
    course["essentials"] = [ essential ]
    document["courses"] = [ course ]
    document
  end

  def open_sidebar_entry(label)
    within("aside nav") { click_on label }
  end

  def upload(path)
    within "turbo-frame#modal dialog[open]" do
      attach_file "import[io]", path
      click_on "Lancer l'import"
    end
    using_wait_time(IMPORT_WAIT) { assert_toast "Import lancé." }
  end

  def close_tracking
    within("turbo-frame#modal dialog[open]") { click_on "Fermer" }
    assert_no_selector "turbo-frame#modal dialog[open]"
  end

  def assert_counters(imported:, skipped:, errors:, total:)
    assert_selector "#import_counter_imported", text: imported.to_s
    assert_selector "#import_counter_skipped", text: skipped.to_s
    assert_selector "#import_counter_errors", text: errors.to_s
    assert_selector "#import_counter_total", text: total.to_s
  end

  test "schools then a course tree arrive through the real buttons, and their classes and draft content show in their screens" do
    open_sidebar_entry "Établissements"
    assert_selector "#schools_empty"

    assert_no_page_reload do
      click_on "Importer des établissements", match: :first
      upload json_file(legacy_schools(PUBLIC_SCHOOL, PRIVATE_SCHOOL), name: "ecoles").path

      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_counters(imported: 2, skipped: 0, errors: 0, total: 2)
        assert_text "Classes générées : 9"
        assert_no_text "sautés"
        assert_no_selector "#import_errors"
      end
      close_tracking
    end

    open_sidebar_entry "Établissements"
    within "#schools_list" do
      assert_selector "tr", count: 2
      click_on PUBLIC_SCHOOL
    end
    within "#school_classrooms" do
      assert_selector "h3", text: "Tle"
      assert_equal (1..6).map { "Tle D #{it}" }, all("li[id^='classroom_'] a").map(&:text)
    end

    open_sidebar_entry "Cours"
    assert_selector "#courses_empty"

    assert_no_page_reload do
      click_on "Importer des cours"
      upload json_file(legacy_course_tree, name: "cours").path

      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_counters(imported: 1, skipped: 0, errors: 0, total: 1)
        assert_text "Fiches essentielles créées : 1"
        assert_text "Exercices créés : 1"
        assert_text "Questions créées : 2"
        assert_text "Propositions créées : 4"
      end
      close_tracking
    end

    open_sidebar_entry "Cours"
    within "#courses_list" do
      assert_selector "li", count: 1
      assert_selector "li", text: /#{COURSE}.*Brouillon/m
      click_on COURSE
    end
    within "#course_essentials" do
      assert_selector "li", text: /#{ESSENTIAL}.*1 exercice.*Brouillon/m
    end

    open_sidebar_entry "Imports"
    assert_selector "#imports tr", count: 2
    assert_selector "#imports tr", text: /#{I18n.t("import_kinds.course_tree")}.*cours.*\.json.*Terminé/m
    assert_selector "#imports tr", text: /Établissements.*ecoles.*\.json.*Terminé/m
  end

  test "a mixed file shows its exact counters and error paths, and only its valid schools are written" do
    create_school(drena: Orm::Drena.find_by!(slug: "drena-abidjan-2"), name: PUBLIC_SCHOOL)
    document = legacy_schools("Lycée Moderne de Cocody", "Lycée Sainte Marie", PUBLIC_SCHOOL, "Lycée Moderne de Cocody",
                              "Lycée Moderne d'Angré")
    document["schools"][1]["name"] = ""
    document["schools"][4]["schooltype"] = "semi-public"
    open_sidebar_entry "Imports"

    assert_no_page_reload do
      click_on "Nouvel import"
      within("#new-import-menu") { click_on "Établissements" }
      upload json_file(document, name: "mixte").path

      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Terminé"
        assert_counters(imported: 1, skipped: 2, errors: 2, total: 5)
        assert_text "Classes générées : 6"
        assert_selector "#import_errors li", count: 2
        assert_selector "#import_errors li", text: /\Aschools\[1\]\.name\s+Valeur obligatoire manquante\.\z/
        assert_selector "#import_errors li", text: /\Aschools\[4\]\.type\s+Valeur non valide\.\z/
      end
      assert_selector "#imports tr", count: 1
    end

    assert_equal [ PUBLIC_SCHOOL, "Lycée Moderne de Cocody" ], Orm::School.order(:name).pluck(:name)
    assert_equal 6, Orm::School.find_by!(name: "Lycée Moderne de Cocody").classrooms.count
    assert_equal 0, Orm::Classroom.where.not(school: Orm::School.where(name: "Lycée Moderne de Cocody")).count
  end

  test "a file whose envelope is wrong ends « Rejeté » and writes nothing" do
    open_sidebar_entry "Imports"

    assert_no_page_reload do
      click_on "Nouvel import"
      within("#new-import-menu") { click_on "Établissements" }
      upload json_file(legacy_course_tree, name: "mauvaise-enveloppe").path

      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text "Rejeté"
        assert_selector "[role=alert]", text: "rejeté en bloc : rien n'a été écrit"
        assert_selector "#import_errors li", text: /\Aformat\s+Le format du fichier ne correspond pas/
        assert_no_selector "#import_counter_imported"
      end
      assert_selector "#imports tr", text: /Établissements.*mauvaise-enveloppe.*\.json.*Rejeté/m
    end

    assert_equal 0, Orm::School.count
    assert_equal 0, Orm::Classroom.count
    assert_equal 0, Orm::Course.count
  end
end
