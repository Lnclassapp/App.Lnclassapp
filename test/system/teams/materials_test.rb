require "application_system_test_case"

# ADR-0034, UDR-0006, UDR-0034 (CA-20, CA-22, CA-26): the team manages the materials in modals, without a page reload.
# The badge of a material takes the colour and the icon of its category, never of its name.
class Teams::MaterialsTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/import_flow_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit materials_path
  end

  def tone_selector(category)
    tone = ComponentsHelper::SUBJECT_CATEGORIES.fetch(category.to_sym).fetch(:tone)
    ComponentsHelper::BADGE_TONES.fetch(tone).fetch(:chip).split.map { %([class~="#{it}"]) }.join
  end

  def category_label(category) = I18n.t("materials.categories.#{category}")

  def submit_modal(label)
    within("turbo-frame#modal dialog[open]") { click_on label }
  end

  test "create a material without a category, then with one; rename it, then change its category" do
    assert_no_page_reload do
      click_on I18n.t("teams.materials.index.new")
      within "turbo-frame#modal dialog[open]" do
        fill_in "material[name]", with: "SVT"
        fill_in "material[shortname]", with: "SVT"
      end
      submit_modal I18n.t("teams.materials.new.submit")

      within "turbo-frame#modal dialog[open]" do
        assert_selector "#material_category_error",
                        text: I18n.t("activemodel.errors.models.dtos/catalog/material_input.attributes.category.inclusion")
        assert_field "material[name]", with: "SVT"
        choose category_label("science")
      end
      submit_modal I18n.t("teams.materials.new.submit")

      assert_toast I18n.t("teams.materials.create.done", name: "SVT")
      assert_no_selector "turbo-frame#modal dialog"
      assert_selector "#material_svt #{tone_selector('science')}", text: "SVT"

      click_menu_action("#material_svt", I18n.t("teams.materials.material_row.edit"))
      within("turbo-frame#modal dialog[open]") { fill_in "material[name]", with: "Sciences de la vie" }
      submit_modal I18n.t("teams.materials.edit.submit")

      assert_toast I18n.t("teams.materials.update.done", name: "Sciences de la vie")
      assert_selector "#material_svt #{tone_selector('science')}", text: "Sciences de la vie"

      click_menu_action("#material_svt", I18n.t("teams.materials.material_row.edit"))
      within("turbo-frame#modal dialog[open]") { choose category_label("other") }
      submit_modal I18n.t("teams.materials.edit.submit")

      assert_selector "#material_svt #{tone_selector('other')}", text: "Sciences de la vie"
      assert_no_selector "#material_svt #{tone_selector('science')}"
    end
  end

  test "on a phone, the table scrolls on its own: the page never scrolls sideways" do
    create_material(name: "Physique-Chimie", shortname: "PC")

    with_mobile_viewport do
      visit materials_path

      assert_selector "#material_physique-chimie"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth")
    end
  end

  test "delete an unused material; the deletion of a used one is refused with its reason, and its row stays" do
    create_material(name: "Latin", shortname: "Lat")
    create_course(material: create_material(name: "Français", shortname: "Fr", category: "literature"))
    visit materials_path

    assert_no_page_reload do
      click_menu_action("#material_latin", I18n.t("teams.materials.material_row.delete"))
      within("#material_latin dialog[open]") { click_on I18n.t("teams.materials.material_row.confirm") }

      assert_toast I18n.t("teams.materials.destroy.done")
      assert_no_selector "#material_latin"

      click_menu_action("#material_francais", I18n.t("teams.materials.material_row.delete"))
      within("#material_francais dialog[open]") { click_on I18n.t("teams.materials.material_row.confirm") }

      assert_toast I18n.t("teams.materials.destroy.referenced")
      assert_selector "#material_francais", text: "Français"
      assert_no_selector "#material_francais dialog[open]"
    end
  end
end
