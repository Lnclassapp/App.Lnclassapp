require "application_system_test_case"

# SC-01, ADR-0036, ADR-0066, UDR-0006: from an empty base, the team creates a DRENA in the modal (slug drena-…), renames
# it without touching its slug, meets the 422 of a taken name and of a name without latin letter, and fails to delete
# a DRENA that has schools — all without a page reload.
class Teams::DrenasTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def fill_drena_modal(name, submit:)
    within "turbo-frame#modal dialog[open]" do
      fill_in "drena[name]", with: name
      click_on submit
    end
  end

  test "create, rename, meet a taken name and a name without letter, then delete an unused DRENA, without a page reload" do
    visit drenas_path
    assert_selector "#drenas_empty", text: "Aucune DRENA pour l'instant"
    assert_no_selector "#drenas tr"

    assert_no_page_reload do
      click_on "Nouvelle DRENA"
      fill_drena_modal("Abidjan 1", submit: "Créer la DRENA")

      assert_toast "DRENA « Abidjan 1 » créée."
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_selector "#drenas tr", count: 1, text: /Abidjan 1\s+drena-abidjan-1\s+0\s+0/
      assert_no_selector "#drenas_empty"

      click_menu_action("#drenas tr", "Modifier", text: "Abidjan 1")
      within("turbo-frame#modal dialog[open]") { assert_selector "#drena_name_hint code", text: "drena-abidjan-1" }
      fill_drena_modal("Abidjan 1 Plateau", submit: "Enregistrer")

      assert_toast "DRENA « Abidjan 1 Plateau » modifiée."
      assert_selector "#drenas tr", count: 1, text: /Abidjan 1 Plateau\s+drena-abidjan-1/

      click_on "Nouvelle DRENA"
      fill_drena_modal("Abidjan 1 Plateau", submit: "Créer la DRENA")

      within "turbo-frame#modal dialog[open]" do
        assert_selector "#drena_name_error", text: "Une DRENA porte déjà ce nom."
        assert_field "drena[name]", with: "Abidjan 1 Plateau"
        fill_in "drena[name]", with: "???"
        click_on "Créer la DRENA"
        assert_selector "#drena_name_error", text: "Le nom doit contenir au moins une lettre ou un chiffre latin."
        click_on "Annuler"
      end
      assert_no_selector "turbo-frame#modal dialog[open]"

      click_menu_action("#drenas tr", "Supprimer", text: "Abidjan 1 Plateau")
      within("dialog[open]") { click_on "Supprimer la DRENA" }

      assert_toast "DRENA « Abidjan 1 Plateau » supprimée."
      assert_no_selector "#drenas tr"
      assert_selector "#drenas_empty", text: "Aucune DRENA pour l'instant"
    end
    assert_equal 0, Orm::Drena.count
  end

  test "deleting a DRENA that has schools is refused with the reason, and its row stays" do
    drena = create_drena(name: "Abidjan 2")
    2.times { create_school(drena:) }
    visit drenas_path

    assert_no_page_reload do
      click_menu_action("#drena_#{drena.public_id}", "Supprimer")
      within("dialog[open]") { click_on "Supprimer la DRENA" }

      within "#toasts [role=alert]" do
        assert_text "La DRENA « Abidjan 2 » a 2 établissements : elle ne peut pas être supprimée."
      end
      assert_no_selector "dialog[open]"
      assert_selector "#drena_#{drena.public_id}", text: /Abidjan 2\s+drena-abidjan-2\s+2\s+0/
    end
    assert Orm::Drena.exists?(drena.id)
  end

  test "the list reads on a phone, its table scrolling alone" do
    create_drena(name: "Abidjan 1")

    with_mobile_viewport do
      visit drenas_path

      assert_selector "h1", text: "DRENA"
      assert_selector "#drenas tr", text: "drena-abidjan-1"
      assert_selector "a", text: "Nouvelle DRENA"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
