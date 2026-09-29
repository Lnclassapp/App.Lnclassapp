require "application_system_test_case"

# FU-01, FU-09, FU-25, FU-45, FU-51 (UDR-0054 §3.1, §3.2, §3.5, §3.9, Lot D1): the team searches the schools while
# typing — only the list reloads, the URL is replaced, the count is announced — sends a DRENA on change, opens a school
# and comes back by « Établissements » to the same filtered list, then copies the management's invitation link.
module Finitions
  class SchoolsSearchTest < ApplicationSystemTestCase
    setup do
      @abidjan = create_drena(name: "Abidjan 1")
      @bouake = create_drena(name: "Bouaké")
      @cocody = create_school(drena: @abidjan, name: "Lycée Moderne de Cocody")
      create_school(drena: @bouake, name: "Collège Cocody-Bouaké")
      create_school(drena: @abidjan, name: "Lycée Classique d'Abidjan")
      sign_in_as create_team_member
      assert_current_path team_home_path
    end

    def total(count) = I18n.t("teams.schools.index.total", count:)
    def history_length = page.evaluate_script("history.length")

    def query_of(uri) = Rack::Utils.parse_query(URI(uri).query)

    test "FU-01, FU-45, FU-51: typing searches after a pause, replaces the URL and announces the count; a list goes on change" do
      visit schools_path
      assert_title "Établissements · Équipe · Lnclass"
      assert_selector "#schools_list tr", count: 3
      assert_no_button I18n.t("teams.schools.filters.submit")

      assert_no_page_reload do
        entries = history_length
        fill_in "filter_search", with: "c"
        sleep 0.6 # plus que le délai de 300 ms : un seul caractère ne part pas (FU-51)
        assert_selector "#schools_list tr", count: 3
        assert_nil query_of(current_url)["search"]

        fill_in "filter_search", with: "coc"
        assert_selector "#schools_list tr", count: 2
        assert_selector "#schools_total[aria-live=polite]", text: total(2)
        assert_current_path(schools_path, ignore_query: true) { |uri| query_of(uri)["search"] == "coc" }
        assert_equal entries, history_length, "la frappe a empilé une entrée d'historique"
        assert_field "filter_search", with: "coc", focused: true

        select "Abidjan 1", from: "filter_drena"
        assert_selector "#schools_list tr", count: 1
        assert_selector "#schools_list tr", text: "Lycée Moderne de Cocody"
        assert_selector "#schools_total", text: total(1)
        assert_current_path(schools_path, ignore_query: true) do |uri|
          query_of(uri).slice("search", "drena") == { "search" => "coc", "drena" => @abidjan.public_id }
        end

        select I18n.t("teams.schools.filters.all_drena"), from: "filter_drena"
        fill_in "filter_search", with: ""
        assert_selector "#schools_list tr", count: 3
        assert_selector "#schools_total", text: total(3)
      end
    end

    test "FU-09: « Établissements » leads back to the filtered list; from a direct link, to the whole list" do
      visit schools_path
      fill_in "filter_search", with: "coc"
      assert_selector "#schools_list tr", count: 2
      select "Abidjan 1", from: "filter_drena"
      assert_selector "#schools_list tr", count: 1

      click_on "Lycée Moderne de Cocody"
      assert_selector "#school_header h1", text: "Lycée Moderne de Cocody"
      assert_title "Lycée Moderne de Cocody · Équipe · Lnclass"
      within("nav[aria-label='#{I18n.t('components.back_link.label')}']") { click_on I18n.t("teams.schools.show.back") }

      assert_selector "#schools_list tr", count: 1
      assert_selector "#schools_list tr", text: "Lycée Moderne de Cocody"
      assert_field "filter_search", with: "coc"
      assert_field "filter_drena", with: @abidjan.public_id
      assert_equal({ "search" => "coc", "drena" => @abidjan.public_id }, query_of(current_url).slice("search", "drena"))

      visit school_path(@cocody.public_id)
      within("nav[aria-label='#{I18n.t('components.back_link.label')}']") { click_on I18n.t("teams.schools.show.back") }
      assert_selector "#schools_list tr", count: 3
      assert_current_path schools_path
    end

    test "FU-25: the link of the management's invitation is copied in one click" do
      page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
      visit school_path(@cocody.public_id)

      link = nil
      assert_no_page_reload do
        click_menu_action "#school_header", I18n.t("teams.schools.header.invite_staff")
        within "turbo-frame#modal dialog[open]" do
          assert_equal page.evaluate_script("document.activeElement.name"), "invitation[contact]"
          fill_in "invitation[contact]", with: "07 99 00 00 09"
          click_on I18n.t("teams.staff_invitations.new.submit")
        end
        within "turbo-frame#modal dialog#staff-invitation-created-modal[open]" do
          link = find_field("invitation-link", readonly: true).value
          click_on "Copier le lien"
        end
        assert_toast "Lien copié."
      end
      assert_equal link, page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
    end
  end
end
