require "application_system_test_case"

# UDR-0042: the actions of a team table row live in a ⋮ menu. « Supprimer » in the menu closes it, opens the row's
# confirmation dialog and deletes; the menu escapes the table's horizontal scroll, on a desk as on a phone, and the
# keyboard goes from the ⋮ button to the dialog and back to the ⋮ button.
class Teams::RowActionsMenuTest < ApplicationSystemTestCase
  setup do
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  # True when the point at the middle of the element is the element itself (or inside it): nothing clips it.
  def reachable?(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector(#{selector.to_json})
        const box = element.getBoundingClientRect()
        const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)
        return box.left >= 0 && box.right <= document.documentElement.clientWidth && element.contains(hit)
      })()
    JS
  end

  test "Supprimer in the menu of the last row opens its confirmation, which deletes the DRENA" do
    create_drena(name: "Abidjan 1")
    last = create_drena(name: "Bouaké")
    visit drenas_path
    menu = "#drena-actions-#{last.public_id}"

    assert_no_page_reload do
      within("#drena_#{last.public_id}") do
        find("button[aria-label='Actions pour Bouaké']").click
        assert_selector "#{menu}[role=menu]", visible: true
        assert_selector "button[aria-controls='#{menu.delete('#')}'][aria-expanded=true]"
        assert reachable?("#{menu} [role=menuitem]:last-child"), "le menu est rogné par le tableau"

        find("#{menu} button[role=menuitem]", text: "Supprimer").click
      end

      assert_no_selector menu, visible: true
      within("dialog#delete-drena-#{last.public_id}[open]") do
        assert_selector "h2", text: "Supprimer la DRENA « Bouaké » ?"
        click_on "Supprimer la DRENA"
      end

      assert_toast "DRENA « Bouaké » supprimée."
      assert_no_selector "#drena_#{last.public_id}"
      assert_selector "#drenas tr", count: 1, text: "Abidjan 1"
    end
  end

  test "keyboard: the ⋮ button opens the menu, the arrows reach Supprimer, Escape gives the focus back to ⋮" do
    drena = create_drena(name: "Abidjan 1")
    visit drenas_path
    button = find("button[aria-label='Actions pour Abidjan 1']")

    button.send_keys(:enter)
    assert_selector "#drena-actions-#{drena.public_id} a[role=menuitem]:focus", text: "Modifier"

    page.active_element.send_keys(:arrow_down)
    assert_selector "#drena-actions-#{drena.public_id} button[role=menuitem]:focus", text: "Supprimer"

    page.active_element.send_keys(:enter)
    assert_selector "dialog#delete-drena-#{drena.public_id}[open]"

    page.active_element.send_keys(:escape)
    assert_no_selector "dialog[open]"
    assert_selector "button[aria-label='Actions pour Abidjan 1'][aria-expanded=false]:focus"
    assert Orm::Drena.exists?(drena.id)
  end

  test "on a phone, the menu of a school row opens whole inside the screen, and the page never scrolls sideways" do
    school = create_school(name: "Lycée Classique d'Abidjan")

    with_mobile_viewport do
      visit schools_path
      within("#school_#{school.public_id}") do
        find("button[aria-haspopup=menu]").click
        assert_selector "[role=menu] [role=menuitem]", count: 3
      end

      assert reachable?("#school-actions-#{school.public_id} [role=menuitem]:first-child"), "le menu sort de l'écran"
      assert reachable?("#school-actions-#{school.public_id} [role=menuitem]:last-child"), "le menu sort de l'écran"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
