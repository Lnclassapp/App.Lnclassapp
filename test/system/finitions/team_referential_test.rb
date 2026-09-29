require "application_system_test_case"

# Finitions UX, Lot C1 (UDR-0054 §3.1 to §3.4): the team's referential screens — levels, series, materials, DRENA and
# the barème — get their tab title, their « Accueil » back link, the focus of their modals and confirmations.
class FinitionsTeamReferentialTest < ApplicationSystemTestCase
  setup do
    seed_referential
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def title(page_name) = "#{page_name} · Équipe · Lnclass"
  def active_id = evaluate_script("document.activeElement.id")
  def active_text = evaluate_script("document.activeElement.textContent").squish

  # FU-10: the back link « Accueil » is the first link of the main content, above the title.
  test "the referential screens lead back to the team home, above their title" do
    { levels_path => "Niveaux", series_index_path => "Séries", materials_path => "Matières", drenas_path => "DRENA",
      classroom_plan_path => "Barème des classes" }.each do |path, name|
      visit path

      assert_title title(name)
      first_link = find("main#main a", match: :first)
      assert_equal "Accueil", first_link.text, "retour de #{name}"
      assert_equal team_home_path, URI(first_link[:href]).path
      assert_selector "main nav[aria-label=Retour] + div h1", text: name
    end
  end

  # FU-04, FU-15: the modal targets its first field, never the close button, and names the tab while open.
  test "the new level modal targets its name field and names the tab until it closes" do
    visit levels_path
    assert_title title("Niveaux")

    click_on "Nouveau niveau"

    assert_selector "dialog#level-modal[open]"
    assert_equal "level_name", active_id
    assert_title title("Nouveau niveau")

    within("dialog#level-modal") { click_on "Annuler" }

    assert_no_selector "dialog#level-modal[open]"
    assert_title title("Niveaux")
  end

  # FU-16: a 422 re-renders the modal with the focus on the faulty field.
  test "a level sent without a name comes back with the focus on the name, marked in error" do
    visit levels_path
    click_on "Nouveau niveau"

    within "dialog#level-modal[open]" do
      fill_in "level[name]", with: "   "
      click_on "Créer le niveau"

      assert_selector "#level_name[aria-invalid=true]"
    end
    assert_equal "level_name", active_id
    assert_title title("Nouveau niveau")
  end

  # FU-18: a confirmation without a field targets « Annuler », and leaves the tab title alone.
  test "the delete confirmation of a level targets Cancel" do
    visit levels_path

    click_menu_action "#level_6eme", "Supprimer"

    assert_selector "dialog#delete-level-6eme[open]"
    assert_equal "Annuler", active_text
    assert_title title("Niveaux")
  end

  test "every modal of the referential targets its first field and names the tab" do
    [ [ series_index_path, -> { click_on "Nouvelle série" }, "series-modal", "series_name", "Nouvelle série" ],
      [ materials_path, -> { click_on "Nouvelle matière" }, "material-modal", "material_name", "Nouvelle matière" ],
      [ drenas_path, -> { click_on "Nouvelle DRENA" }, "drena-modal", "drena_name", "Nouvelle DRENA" ],
      [ levels_path, -> { click_menu_action "#level_6eme", "Modifier" }, "level-modal", "level_name", "Modifier le niveau" ],
      [ classroom_plan_path, -> { click_menu_action "#classroom_plan_line_6eme", "Modifier" }, "classroom-plan-line-modal",
        "classroom_plan_line_public_count", "Barème de « 6ème »" ] ].each do |path, open, modal, field, name|
      visit path
      open.call

      assert_selector "dialog##{modal}[open]"
      assert_equal field, active_id, "focus de #{name}"
      assert_title title(name)
    end
  end

  # FU-05: a modal opened by its URL names the page itself.
  test "a modal opened by its URL has its own document title" do
    { new_level_path => "Nouveau niveau", new_drena_path => "Nouvelle DRENA", new_series_path => "Nouvelle série",
      new_material_path => "Nouvelle matière" }.each do |path, name|
      visit path

      assert_selector "dialog[open]"
      assert_equal title(name), evaluate_script("document.querySelector('title').textContent")
    end
  end

  # FU-22: the « Hors barème » badge loses its title and gets an info tip named after it.
  test "the badge of a level outside the generation has an info tip, and no title" do
    Orm::ClassroomPlanEntry.where(level: Orm::Level.find_by!(slug: "6eme")).delete_all
    visit levels_path

    within "#level_6eme" do
      assert_no_selector "[title]"
      find("summary", text: "Aide : Hors barème", visible: :all).click
      assert_text "Ce niveau n'est pas utilisé pour générer les classes des établissements."
    end
  end
end
