require "application_system_test_case"

# RM-01, RM-06, RM-15 (ADR-0096, UDR-0104, UDR-0105): the admin of the team regenerates the codes of the whole list after
# typing their number, then filters a DRENA and regenerates the links of its classrooms in one confirmation; each launch
# leads to its report. The card entry, the rights and the jobs are proved by the controller and job tests.
class Teams::CodeRegenerationTest < ApplicationSystemTestCase
  FORM = "teams.code_regenerations.form".freeze

  setup do
    abidjan = create_drena(name: "Abidjan 1")
    level = create_level
    [ "Lycée Moderne de Cocody", "Collège Saint Paul" ].each do |name|
      create_classroom(school: create_school(drena: abidjan, name:), level:, name: "6e 1")
    end
    create_school(drena: create_drena(name: "Bouaké"), name: "Lycée de Bouaké")
    sign_in_as create_team_member(team_role: "admin")
    assert_current_path team_home_path
  end

  def open_codes_menu(action)
    find("button[aria-controls=schools-codes-menu]").click
    within("#schools-codes-menu") { click_on action }
  end

  test "RM-06, RM-01, RM-15: the whole list after typing its number, then the links of a filtered DRENA in one confirmation" do
    visit schools_path
    open_codes_menu "Régénérer les codes d'établissement"
    within("dialog#code-regeneration-modal[open]") do
      assert_text "Régénérer le code de 3 établissements ?"
      fill_in "Tapez 3 pour confirmer", with: "2"
      click_on I18n.t("#{FORM}.confirm.school_codes")
      assert_text "Tapez 3 pour confirmer."
      fill_in "Tapez 3 pour confirmer", with: "3"
      click_on I18n.t("#{FORM}.confirm.school_codes")
    end
    assert_toast "Régénération des codes lancée."
    assert_selector "#code_regeneration_selection", text: "Sélection : Tous les établissements"

    visit schools_path
    select "Abidjan 1", from: "filter_drena"
    assert_text "2 établissements"
    open_codes_menu "Régénérer les liens des classes"
    within("dialog#code-regeneration-modal[open]") do
      assert_text "Régénérer le lien de 2 classes de la DRENA Abidjan 1 ?"
      assert_no_field "Tapez 2 pour confirmer"
      click_on I18n.t("#{FORM}.confirm.classroom_links")
    end
    assert_toast "Régénération des liens des classes lancée."
    assert_selector "#code_regeneration_selection", text: /DRENA Abidjan 1 · année/
    assert_equal({ "school_codes" => 3, "classroom_links" => 2 }, Orm::ImportReport.pluck(:kind, :details).to_h { [ it.first, it.last["expected_count"] ] })
  end
end
