require "application_system_test_case"

# GC-01, GC-02, ADR-0056, UDR-0043: from the schools screen, the team reads who is concerned, confirms, lands on the
# report, and once the job has run, the schools without classrooms have theirs while the others are unchanged.
class School::GenerateClassroomsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  REPORT_WAIT = 10

  setup do
    seed_referential
    drena = create_drena(name: "Abidjan 2")
    @lycee = create_school(drena:, name: "Lycée Moderne de Cocody")
    @college = create_school(drena:, name: "Collège Saint Paul", school_type: "private", cycle: "first")
    @equipped = create_school(drena:, name: "Lycée Classique d'Abidjan")
    @kept = Array.new(3) { create_classroom(school: @equipped, name: "Terminale #{it + 1}") }
    sign_in_as create_team_member
    visit schools_path
  end

  def classrooms_of(school) = Orm::Classroom.where(school:)

  # UDR-0043, UDR-0045 (amendments of 2026-09-28): the generation and the barème live in the « Classes » menu of the header.
  def open_generation
    find("button[aria-controls=schools-classrooms-menu]").click
    within("#schools-classrooms-menu") { click_on "Générer les classes manquantes" }
  end

  test "the confirmation says who is concerned; once confirmed and run, only the schools without classrooms get theirs" do
    open_generation

    within "dialog#generate-classrooms-modal[open]" do
      assert_selector "h2", text: "Générer les classes manquantes ?"
      assert_text "sans aucune classe de l'année scolaire #{current_school_year}"
      assert_text "Les autres établissements ne sont jamais modifiés"
      click_on "Lancer la génération"
    end

    assert_toast "Génération des classes lancée."
    assert_selector "h1", text: "Génération des classes"
    assert_equal 3, Orm::Classroom.count

    perform_enqueued_jobs

    using_wait_time(REPORT_WAIT) do
      within "turbo-frame#import_status" do
        assert_text "Terminé"
        assert_selector "#import_counter_imported", text: "2"
        assert_text "Classes générées : 89"
      end
    end
    assert_equal [ 77, 12 ], [ classrooms_of(@lycee).count, classrooms_of(@college).count ]
    assert_equal @kept.map(&:id).sort, classrooms_of(@equipped).ids.sort
  end

  test "Annuler closes the confirmation, and nothing is launched" do
    open_generation

    within("dialog#generate-classrooms-modal[open]") { click_on "Annuler" }

    assert_no_selector "dialog#generate-classrooms-modal[open]"
    assert_equal 0, Orm::ImportReport.count
    assert_no_enqueued_jobs
  end

  # Owner's request (2026-09-28): the « Classes » menu sits to the right of the import button, on the same line, at 1280 px.
  def box(selector) = page.evaluate_script("(({ top, left }) => ({ top: Math.round(top), left }))(document.querySelector(#{selector.to_json}).getBoundingClientRect())")

  test "at 1280 px, the « Classes » menu is on the line of the import button, to its right" do
    page.current_window.resize_to(1280, 900)
    visit schools_path

    import = box("#schools-header-actions a[href*='kind=schools']")
    menu = box("button[aria-controls=schools-classrooms-menu]")
    assert_equal import["top"], menu["top"], "le menu passe sous l'import"
    assert_operator menu["left"], :>, import["left"]
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "on a phone, the « Classes » menu opens the confirmed generation, and leads to the barème" do
    with_mobile_viewport do
      visit schools_path
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"

      open_generation
      within("dialog#generate-classrooms-modal[open]") { click_on "Lancer la génération" }
      assert_toast "Génération des classes lancée."
      assert_equal 1, Orm::ImportReport.where(kind: "classrooms").count

      visit schools_path
      find("button[aria-controls=schools-classrooms-menu]").click
      within("#schools-classrooms-menu") { click_on "Barème des classes" }
      assert_selector "h1", text: "Barème des classes"
    end
  end
end
