require "application_system_test_case"

# UDR-0113 §3.2, §3.3 (PRD : chemin nominal 7, puis 2 et 3) : sur un téléphone de 390 px, un visiteur ouvre /niveaux,
# choisit la Terminale, voit ses séries et ses cours par matière, puis suit « Voir les N fiches de cours » ; aucune page ne défile
# sur le côté.
class PublicLevelPagesJourneyTest < ApplicationSystemTestCase
  setup do
    @referential = seed_referential
    tle = @referential[:levels].fetch("tle")
    maths = @referential[:materials].fetch("mathematiques")
    8.times { |index| create_course(name: "Suites #{index}", level: tle, material: maths, series: @referential[:series].fetch("d")) }
    create_course(name: "La conscience", level: tle, material: @referential[:materials].fetch("philosophie"))
  end

  def assert_no_sideways_scroll(label)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "#{label} défile sur le côté"
  end

  test "a visitor goes from /niveaux to the Terminale, then to all its mathematics courses, on a phone" do
    with_mobile_viewport do
      visit public_levels_path
      assert_selector "h1", text: "Les fiches de cours par niveau"
      assert_no_sideways_scroll "/niveaux"

      click_on "Tle"
      assert_selector "h1", text: "Fiches de cours de Tle"
      assert_selector "#level_series a", text: "Tle D"
      assert_selector "#group_mathematiques li", count: 6
      assert_no_sideways_scroll "/niveaux/tle"

      click_on "Voir les 8 fiches de cours"
      assert_selector "h1", text: "Mathématiques en Tle"
      assert_selector "#material_groups article", count: 8
      assert_current_path public_material_path("mathematiques", niveau: "tle")
      assert_no_sideways_scroll "/matieres/mathematiques?niveau=tle"
    end
  end
end
