require "application_system_test_case"

# ADR-0098, UDR-0110, UDR-0111 : sur la fiche d'un établissement, l'équipe ouvre « Modifier la classe » dans le menu ⋮ de
# « 6ème 3 », voit un nom pris refusé sous le champ, renomme en « 6ème A » et relève le plafond. Le « + » qui ajoute ensuite
# « 6ème 3 » est prouvé au niveau contrôleur (Teams::LevelClassroomsControllerTest) : il n'a rien de propre au navigateur.
class School::ClassroomSettingsTest < ApplicationSystemTestCase
  setup do
    levels = seed_referential[:levels]
    @school = create_school(name: "Lycée Classique d'Abidjan", cycle: "both")
    @sixths = (1..3).map { create_classroom(school: @school, level: levels["6eme"], name: "6ème #{it}") }
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  # Sous charge, une réponse Turbo dépasse parfois l'attente par défaut de Capybara.
  RESPONSE_WAIT = 10

  def assert_toast(text) = using_wait_time(RESPONSE_WAIT) { super }

  # La page peut encore s'hydrater quand le premier clic arrive (comme Teams::ClassroomArchivalTest).
  def open_edit(classroom)
    3.times do
      find("button[aria-label='Actions de la classe #{classroom.name}']").click
      return find("#classroom-menu-#{classroom.public_id} a[role=menuitem]", text: "Modifier la classe", wait: 2).click
    rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
      next
    end
    flunk "le menu de #{classroom.name} ne s'est pas ouvert"
  end

  test "renommer « 6ème 3 » en « 6ème A » après un nom pris" do
    visit school_path(@school.public_id)
    open_edit(@sixths.last)

    within "dialog#classroom-settings-modal[open]", wait: RESPONSE_WAIT do
      assert_selector "h2", text: "Modifier la classe 6ème 3"
      assert_selector "#classroom-settings-prefix", text: "6ème"
      fill_in "Nom", with: "1"
      click_on "Enregistrer"
      assert_text "Ce nom est déjà pris dans l'établissement cette année (classes archivées comprises).", wait: RESPONSE_WAIT

      fill_in "Nom", with: "A"
      fill_in "Plafond d'élèves", with: "95"
      click_on "Enregistrer"
    end

    assert_toast "Classe 6ème A enregistrée."
    assert_no_selector "dialog#classroom-settings-modal[open]"
    assert_selector "li#classroom_#{@sixths.last.public_id}", text: "6ème A"
    # La fiche re-demandée par morphing garde les boutons « Copier le lien » que le contrôleur clipboard avait montrés.
    @sixths.each { assert_selector "li#classroom_#{it.public_id} button", text: "Copier le lien" }
    assert_equal [ "6ème A", 95 ], @sixths.last.reload.then { [ it.name, it.max_students ] }
  end
end
