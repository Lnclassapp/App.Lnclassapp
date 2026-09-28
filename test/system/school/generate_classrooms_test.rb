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

  test "the confirmation says who is concerned; once confirmed and run, only the schools without classrooms get theirs" do
    click_on "Générer les classes manquantes"

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
    click_on "Générer les classes manquantes"

    within("dialog#generate-classrooms-modal[open]") { click_on "Annuler" }

    assert_no_selector "dialog#generate-classrooms-modal[open]"
    assert_equal 0, Orm::ImportReport.count
    assert_no_enqueued_jobs
  end
end
