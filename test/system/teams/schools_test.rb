require "application_system_test_case"

# ADR-0030, ADR-0036, UDR-0006, UDR-0036 (SC-03 to SC-07): the team browses the national list, filters it, edits,
# deactivates and deletes schools in place, without a page reload. No button creates a school: the list's main action
# is the import.
class Teams::SchoolsTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/import_flow_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    @abidjan = create_drena(name: "Abidjan 1")
    @bouake = create_drena(name: "Bouaké")
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def row_scope = "teams.schools.school_row"
  def header_scope = "teams.schools.header"

  test "SC-03: the main action of the list opens the import modal, and no button creates a school" do
    create_school(drena: @abidjan, name: "Lycée Classique")
    visit schools_path

    assert_no_selector "a[href$='/schools/new']"
    assert_no_page_reload do
      click_on I18n.t("teams.schools.index.import")

      within "turbo-frame#modal dialog#import-upload-modal[open]" do
        assert_selector "input[name='import[kind]'][value=schools]", visible: :all
        click_on I18n.t("teams.imports.new.cancel")
      end
      assert_no_selector "turbo-frame#modal dialog[open]"
    end
  end

  test "SC-04, FU-45: filter the list by DRENA, type and name as they change; the URL keeps the filters, no page reload" do
    create_school(drena: @abidjan, name: "Lycée Classique", sigle: "LCA", school_type: "public", national_code: "012345")
    create_school(drena: @abidjan, name: "Collège Moderne de Cocody", school_type: "private", cycle: "first")
    create_school(drena: @bouake, name: "Lycée Municipal", school_type: "private")
    visit schools_path
    assert_selector "#schools_list tr", count: 3
    # IE-21 (UDR-0079 §3.8 bis) : plus de colonne « Code d'établissement » ; la recherche porte sur le nom ou le sigle.
    assert_no_selector "thead th", text: "Code d'établissement"
    assert_selector "label[for=filter_search]", text: "Nom ou sigle"
    # UDR-0054 §3.9 : avec JavaScript, « Filtrer » s'efface ; chaque liste part au changement, la frappe après une pause.
    assert_no_button I18n.t("teams.schools.filters.submit")

    assert_no_page_reload do
      select "Abidjan 1", from: "filter_drena"
      assert_selector "#schools_list tr", count: 2
      select I18n.t("school_types.private"), from: "filter_school_type"

      assert_selector "#schools_list tr", count: 1
      assert_selector "#schools_list tr", text: "Collège Moderne de Cocody"
      assert_selector "#schools_total", text: I18n.t("teams.schools.index.total", count: 1)
      assert_current_path(schools_path, ignore_query: true) do |uri|
        Rack::Utils.parse_query(uri.query).slice("drena", "school_type") == { "drena" => @abidjan.public_id, "school_type" => "private" }
      end

      select I18n.t("teams.schools.filters.all_drena"), from: "filter_drena"
      assert_selector "#schools_list tr", count: 2
      select I18n.t("teams.schools.filters.all_school_type"), from: "filter_school_type"
      assert_selector "#schools_list tr", count: 3
      fill_in "filter_search", with: "lycee"

      assert_selector "#schools_list tr", count: 2
      assert_no_selector "#schools_list tr", text: "Collège"

      fill_in "filter_search", with: "introuvable"

      assert_selector "#schools_empty", text: I18n.t("teams.schools.index.no_match_title")

      fill_in "filter_search", with: "LCA"
      assert_selector "#schools_list tr", count: 1
      assert_selector "#schools_list tr", text: "Lycée Classique"

      # IE-21 : le code national ne trouve plus l'établissement.
      fill_in "filter_search", with: "012345"
      assert_selector "#schools_empty", text: I18n.t("teams.schools.index.no_match_title")
    end
  end

  test "SC-05, SC-06, SC-09: edit a school from its page — the header changes, the classrooms stay — then deactivate it" do
    school = create_school(drena: @abidjan, name: "Lycée Classique", school_type: "public", cycle: "both")
    create_school(drena: @abidjan, name: "Lycée Moderne")
    classroom = create_classroom(school:, level: create_level(name: "Tle"), name: "Tle D 1")
    visit school_path(school.public_id)
    assert_selector "#classroom_#{classroom.public_id}", text: "Tle D 1"

    assert_no_page_reload do
      click_menu_action("#school_header", I18n.t("#{header_scope}.edit"))
      within "turbo-frame#modal dialog[open]" do
        fill_in "school[name]", with: "Lycée Moderne"
        click_on I18n.t("teams.schools.edit.submit")

        assert_selector "#school_name_error",
                        text: I18n.t("activemodel.errors.models.dtos/school/school_input.attributes.name.taken")
        fill_in "school[name]", with: "Lycée Classique d'Abidjan"
        assert_no_select "school[cycle]"
        assert_checked_field I18n.t("teams.schools.cycles.both")
        choose I18n.t("teams.schools.cycles.first")
        select "Bouaké", from: "school[drena_public_id]"
        click_on I18n.t("teams.schools.edit.submit")
      end

      assert_toast I18n.t("teams.schools.update.done", name: "Lycée Classique d'Abidjan")
      assert_no_selector "turbo-frame#modal dialog[open]"
      within "#school_header" do
        assert_selector "h1", text: "Lycée Classique d'Abidjan"
        assert_text "Bouaké"
        assert_text I18n.t("teams.schools.cycles.first")
      end
      assert_selector "#classroom_#{classroom.public_id}", text: "Tle D 1"

      click_menu_action("#school_header", I18n.t("#{header_scope}.deactivate"))
      within("#school_header dialog[open]") { click_on I18n.t("#{header_scope}.confirm_deactivate") }

      assert_toast I18n.t("teams.schools.deactivate.done", name: "Lycée Classique d'Abidjan")
      within "#school_header" do
        assert_text I18n.t("school_statuses.inactive")
        assert_no_link I18n.t("#{header_scope}.add_classroom")
        find("button[aria-haspopup=menu]").click
        within("[role=menu]") do
          assert_link I18n.t("#{header_scope}.edit")
          assert_no_button I18n.t("#{header_scope}.deactivate")
        end
      end
    end
    assert_equal 1, Orm::Classroom.where(school_id: school.id).count
  end

  test "SC-06, SC-07: edit and deactivate from the list; deleting a used school is refused, an unused one disappears" do
    used = create_school(drena: @abidjan, name: "Lycée Classique")
    create_student(classroom: create_classroom(school: used))
    unused = create_school(drena: @abidjan, name: "Lycée Moderne")
    visit schools_path

    assert_no_page_reload do
      click_menu_action("#school_#{unused.public_id}", I18n.t("#{row_scope}.edit"))
      within("turbo-frame#modal dialog[open]") do
        select I18n.t("school_types.mixed"), from: "school[school_type]"
        click_on I18n.t("teams.schools.edit.submit")
      end
      assert_toast I18n.t("teams.schools.update.done", name: "Lycée Moderne")
      assert_selector "#school_#{unused.public_id}", text: I18n.t("school_types.mixed")

      click_menu_action("#school_#{used.public_id}", I18n.t("#{row_scope}.delete"))
      within("turbo-frame#modal dialog#delete-school-#{used.public_id}[open]") { click_on I18n.t("teams.schools.deletion.confirm") }

      assert_toast I18n.t("teams.schools.destroy.referenced")
      assert_selector "#school_#{used.public_id}", text: "Lycée Classique"
      assert_no_selector "turbo-frame#modal dialog[open]"

      click_menu_action("#school_#{used.public_id}", I18n.t("#{row_scope}.deactivate"))
      within("turbo-frame#modal dialog#deactivate-school-#{used.public_id}[open]") { click_on I18n.t("teams.schools.deactivation.confirm") }

      assert_toast I18n.t("teams.schools.deactivate.done", name: "Lycée Classique")
      assert_selector "#school_#{used.public_id}", text: I18n.t("school_statuses.inactive")

      click_menu_action("#school_#{unused.public_id}", I18n.t("#{row_scope}.delete"))
      within("turbo-frame#modal dialog#delete-school-#{unused.public_id}[open]") { click_on I18n.t("teams.schools.deletion.confirm") }

      assert_toast I18n.t("teams.schools.destroy.done")
      assert_no_selector "#school_#{unused.public_id}"
    end
    assert Orm::School.exists?(used.id)
  end

  test "SC-07: deleting the last school of a filter updates the count and shows the empty state, filters kept" do
    create_school(drena: @bouake, name: "Lycée Municipal")
    last = create_school(drena: @abidjan, name: "Lycée Moderne")
    visit schools_path(drena: @abidjan.public_id)
    assert_selector "#schools_total", text: I18n.t("teams.schools.index.total", count: 1)

    assert_no_page_reload do
      click_menu_action("#school_#{last.public_id}", I18n.t("#{row_scope}.delete"))
      within("turbo-frame#modal dialog#delete-school-#{last.public_id}[open]") { click_on I18n.t("teams.schools.deletion.confirm") }

      assert_toast I18n.t("teams.schools.destroy.done")
      assert_selector "#schools_empty", text: I18n.t("teams.schools.index.no_match_title")
      assert_selector "#schools_total", text: I18n.t("teams.schools.index.total", count: 0)
      assert_no_selector "#schools_list"
      assert_field "filter_drena", with: @abidjan.public_id
    end
    assert_current_path schools_path(drena: @abidjan.public_id)
  end

  test "CR-04, CR-06, CR-07: the cycle of a school is a radio group set to its saved value, chosen by keyboard, even on a phone" do
    school = create_school(drena: @abidjan, name: "Collège Moderne", cycle: "first")

    with_mobile_viewport do
      visit schools_path
      assert_selector "select#filter_cycle option:checked", text: I18n.t("teams.schools.filters.all_cycle")
      assert_no_selector "#schools-filters input[type=radio]"

      assert_no_page_reload do
        click_menu_action("#school_#{school.public_id}", I18n.t("#{row_scope}.edit"))
        within "turbo-frame#modal dialog[open]" do
          within("fieldset#school_cycle", text: Dtos::School::SchoolInput.human_attribute_name(:cycle)) do
            assert_checked_field I18n.t("teams.schools.cycles.first")
            options = all("label", count: 2)
            assert(options.all? { |option| option.native.rect.height >= 48 })
          end
          find_field(I18n.t("teams.schools.cycles.first")).send_keys(:down)
          assert_checked_field I18n.t("teams.schools.cycles.both")
          click_on I18n.t("teams.schools.edit.submit")
        end
        assert_toast I18n.t("teams.schools.update.done", name: "Collège Moderne")
      end
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end
    assert_equal "both", Orm::School.find_by!(public_id: school.public_id).cycle
  end

  test "on a phone, neither the list nor a school's page scrolls sideways" do
    school = create_school(drena: @abidjan, name: "Lycée Classique d'Abidjan", sigle: "LCA")
    create_classroom(school:, name: "6ème 1")

    with_mobile_viewport do
      visit schools_path
      assert_selector "#school_#{school.public_id}"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth")

      visit school_path(school.public_id)
      assert_selector "#school_header"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth")
    end
  end
end
