require "application_system_test_case"

# CA-16, CA-18, UDR-0006, UDR-0032: the team creates, renames and deletes a level, and fails to delete a used one,
# in modals and Turbo Streams, without a page reload.
class Teams::LevelsTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/import_flow_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  # PRD §4: messages are compared through their locale key, never written out in the test.
  def tl(key, **) = I18n.t("teams.levels.#{key}", **)

  def fill_level(name:, position: nil, cycle: nil)
    fill_in "level[name]", with: name
    fill_in "level[position]", with: position if position
    choose tl("cycles.#{cycle}") if cycle
  end

  test "create, rename, then delete a blank level, in position order, without a page reload" do
    create_level(name: "5ème", position: 2, cycle: "first")
    visit levels_path

    assert_no_page_reload do
      click_on tl("index.new")
      within "turbo-frame#modal dialog[open]" do
        assert_field "level[position]", with: "3"
        fill_level(name: "6ème", position: "1", cycle: "first")
        click_on tl("new.submit")
      end

      assert_toast tl("create.created", name: "6ème")
      assert_no_selector "dialog[open]"
      assert_selector "#levels tr:first-child#level_6eme", text: "6eme"

      click_menu_action("#level_6eme", tl("level_row.edit"))
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#level-code", text: "6eme"
        fill_level(name: "Sixième")
        click_on tl("edit.submit")
      end

      assert_toast tl("update.updated", name: "Sixième")
      assert_no_selector "dialog[open]"
      # D1 (owner, 2026-09-28): a 6ème created on screen gets its barème defaults, so no « Hors barème » badge.
      assert_selector "#level_6eme", text: /Sixième\s+6eme/
      assert_no_selector "#level_6eme [data-generation]"

      click_menu_action("#level_6eme", tl("level_row.delete"))
      within("dialog#delete-level-6eme[open]") { click_on tl("level_row.delete_confirm") }

      assert_toast tl("destroy.deleted")
      assert_no_selector "#level_6eme"
      assert_selector "#levels tr", count: 1
    end
  end

  test "a name already taken reopens the modal with its error (422), without a page reload" do
    create_level(name: "6ème", position: 1, cycle: "first")
    visit levels_path

    assert_no_page_reload do
      click_on tl("index.new")
      within "turbo-frame#modal dialog[open]" do
        fill_level(name: "6ème", cycle: "first")
        click_on tl("new.submit")

        assert_selector "#level_name_error",
                        text: I18n.t("activemodel.errors.models.dtos/catalog/level_input.attributes.name.taken")
        assert_field "level[name]", with: "6ème"
      end
    end
    assert_equal 1, Orm::Level.count
  end

  test "a level used by a course cannot be deleted: the reason is given and the row stays" do
    create_course(level: create_level(name: "Tle", position: 7, cycle: "second"))
    visit levels_path

    assert_no_page_reload do
      click_menu_action("#level_tle", tl("level_row.delete"))
      within("dialog#delete-level-tle[open]") { click_on tl("level_row.delete_confirm") }

      assert_toast tl("destroy.referenced", name: "Tle", usage: "1 cours")
      assert_no_selector "dialog[open]"
      assert_selector "#level_tle", text: "Tle"
    end
    assert_equal 1, Orm::Level.count
  end

  test "CR-01, CR-03: the cycle is a radio group, first cycle checked; the keyboard picks the second one" do
    visit levels_path

    assert_no_page_reload do
      click_on tl("index.new")
      within "turbo-frame#modal dialog[open]" do
        assert_no_select "level[cycle]"
        within("fieldset#level_cycle", text: Dtos::Catalog::LevelInput.human_attribute_name(:cycle)) do
          assert_checked_field tl("cycles.first")
          assert_unchecked_field tl("cycles.second")
        end
        fill_level(name: "Tle", position: "7")
        find_field(tl("cycles.first")).send_keys(:right)

        assert_checked_field tl("cycles.second")
        assert_equal "level_cycle_second", page.evaluate_script("document.activeElement.id")
        click_on tl("new.submit")
      end
      assert_toast tl("create.created", name: "Tle")
    end
    assert_equal "second", Orm::Level.find_by!(slug: "tle").cycle

    click_menu_action("#level_tle", tl("level_row.edit"))
    within("turbo-frame#modal dialog[open]") { assert_checked_field tl("cycles.second") }
  end

  test "CR-06: on a phone, each cycle option is a 48 px target and the modal does not widen the page" do
    with_mobile_viewport do
      visit levels_path
      click_on tl("index.new")

      within "turbo-frame#modal dialog[open]" do
        options = all("fieldset#level_cycle label", count: 2)
        assert(options.all? { |option| option.native.rect.height >= 48 })
        assert_equal options.first.native.rect.width, options.last.native.rect.width
      end
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end
  end

  test "on a phone, only the table scrolls sideways, never the page" do
    create_level(name: "Tle", position: 7, cycle: "second")

    with_mobile_viewport do
      visit levels_path

      assert_selector "#level_tle"
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end
  end
end
