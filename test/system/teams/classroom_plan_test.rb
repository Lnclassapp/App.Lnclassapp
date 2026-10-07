require "application_system_test_case"

# BC-01, BC-02, BC-03, BC-05, BC-06, UDR-0045: the team changes a count of the barème from the ⋮ menu of its line, in a
# modal, without a page reload; the next generation gives that count to a school without classrooms, while a school
# already equipped keeps its classrooms.
class Teams::ClassroomPlanTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  REPORT_WAIT = 10

  setup do
    seed_referential
    drena = create_drena(name: "Abidjan 2")
    @lycee = create_school(drena:, name: "Lycée Moderne de Cocody")
    @equipped = create_school(drena:, name: "Lycée Classique d'Abidjan")
    @kept = Array.new(3) { create_classroom(school: @equipped, level: Orm::Level.find_by!(slug: "6eme"), name: "6ème #{it + 1}") }
    sign_in_as create_team_member
  end

  def classrooms_of(school) = Orm::Classroom.where(school:)

  test "change a count from the menu of its line, then generate: the school without classrooms gets the new count" do
    visit teams_referential_path
    within("#team_referential") { click_on "Barème des classes" }

    assert_selector "h1", text: "Barème des classes"
    assert_text "Les classes déjà créées ne changent pas"
    within("#classroom_plan_total_public_both") { assert_text "77" }

    assert_no_page_reload do
      click_menu_action "#classroom_plan_line_6eme", "Modifier"
      within "dialog#classroom-plan-line-modal[open]" do
        assert_selector "h2", text: "Barème de « 6ème »"
        fill_in "Public", with: "6"
        click_on "Enregistrer"
      end

      assert_toast "Barème de « 6ème » enregistré."
      assert_no_selector "dialog#classroom-plan-line-modal[open]"
      within("#classroom_plan_line_6eme") { assert_text "6" }
      within("#classroom_plan_total_public_both") { assert_text "79" }
      within("#classroom_plan_total_public_first") { assert_text "30" }
    end

    visit schools_path
    find("button[aria-controls=schools-classrooms-menu]").click
    within("#schools-classrooms-menu") { click_on "Générer les classes manquantes" }
    within("dialog#generate-classrooms-modal[open]") { click_on "Lancer la génération" }
    assert_toast "Génération des classes lancée."
    perform_enqueued_jobs

    using_wait_time(REPORT_WAIT) do
      within("turbo-frame#import_status") { assert_text "Classes générées : 79" }
    end
    assert_equal 79, classrooms_of(@lycee).count
    assert_equal 6, classrooms_of(@lycee).joins(:level).where(levels: { slug: "6eme" }).count
    assert_equal @kept.map(&:id).sort, classrooms_of(@equipped).ids.sort
  end

  test "the « Classes » menu of the schools screen leads to the barème" do
    visit schools_path
    find("button[aria-controls=schools-classrooms-menu]").click
    within("#schools-classrooms-menu") { click_on "Barème des classes" }

    assert_selector "h1", text: "Barème des classes"
  end

  test "D1: link a series in the matrix, and the barème shows 6 and 3 for it without any entry by hand" do
    visit series_index_path

    find("#level_series_1ere_a button[aria-pressed=false]").click
    assert_selector "#level_series_1ere_a button[aria-pressed=true]"

    visit classroom_plan_path
    within("#classroom_plan_line_1ere_a") { assert_text(/1ère\s+A\s+6\s+3/) }
    assert_no_selector "#classroom_plan_line_1ere_a [data-plan=undefined]"
  end

  test "an invalid count reopens the modal with its error, and nothing changes" do
    visit classroom_plan_path

    click_menu_action "#classroom_plan_line_tle_d", "Modifier"
    within "dialog#classroom-plan-line-modal[open]" do
      fill_in "Privé et mixte", with: "31"
      assert_not page.evaluate_script("document.getElementById('classroom-plan-line-form').checkValidity()"), "le navigateur refuse 31"
      # Past the browser's own check (max 30), the server answers 422 with the error under the field.
      page.execute_script("document.getElementById('classroom-plan-line-form').noValidate = true")
      click_on "Enregistrer"
      assert_selector "#classroom_plan_line_private_count_error"
    end

    assert_equal 3, Orm::ClassroomPlanEntry.joins(:level, :series).find_by!(school_type: "private", levels: { slug: "tle" }, series: { slug: "d" }).count
  end

  test "on a phone, the page never scrolls sideways and the menu still opens the modal" do
    with_mobile_viewport do
      visit classroom_plan_path

      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
      click_menu_action "#classroom_plan_line_1ere_d", "Modifier"
      assert_selector "dialog#classroom-plan-line-modal[open]", text: "Barème de « 1ère D »"
    end
  end
end
