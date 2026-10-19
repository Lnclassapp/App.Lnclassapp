require "application_system_test_case"

# CC-11 (UDR-0114 §3.3) : 24 cartes, puis les suivantes quand le visiteur descend, sans rechargement ; le titre d'un niveau
# déjà ouvert n'est pas répété. CC-10 : une pastille de niveau filtre la page et l'adresse le garde.
class PublicMaterialPagesJourneyTest < ApplicationSystemTestCase
  setup do
    referential = seed_referential
    maths = referential[:materials].fetch("mathematiques")
    6.times { |index| create_course(name: format("Cours 3e %02d", index), level: referential[:levels].fetch("3eme"), material: maths) }
    24.times { |index| create_course(name: format("Cours Tle %02d", index), level: referential[:levels].fetch("tle"), material: maths) }
  end

  test "a visitor scrolls down a material: the next cards load in place, then a level pill filters the page" do
    # À 390 px, les cartes tiennent sur une colonne : le frame de la page 2 est hors de l'écran à l'arrivée (ADR-0076 §4.2).
    with_mobile_viewport do
      visit public_material_path("mathematiques")
      assert_selector "#material_groups article", count: 24

      assert_no_page_reload do
        scroll_to find("turbo-frame#material_courses_page_2")
        assert_selector "turbo-frame#material_courses_page_2 article", count: 6
      end
      assert_selector "#material_groups h2", text: "Tle", count: 1

      within("#material_levels") { click_on "3ème · 6" }
      assert_selector "h1", text: "Mathématiques en 3ème"
      assert_selector "#material_groups article", count: 6
      assert_current_path public_material_path("mathematiques", niveau: "3eme")
    end
  end
end
