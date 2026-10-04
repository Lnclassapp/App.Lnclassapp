require "application_system_test_case"

# RE-01, RE-02, RE-03 (UDR-0068 §3.2 to §3.4): the team's configuration — Référentiel, Imports — leaves the daily
# destinations. On a wide screen it is the second card of the sidebar, « Configuration »; on a 390 px phone, the last
# case of the bottom bar, « Plus », opens upwards a menu of the same entries, and is current on each of their pages.
# AN-22 (chantier annonces, UDR-0071 §3.1 and §4): « Annonces » closes the destinations; the bottom bar has 6 cases.
# The links of the tiles, the aria-current of each page and the 403 are checked at the controller level
# (test/controllers/teams/referentials_controller_test.rb, teams/imports_controller_test.rb): the system suite has a budget.
class Teams::ConfigurationNavigationTest < ApplicationSystemTestCase
  MAIN_NAV = "aside nav:not(#sidebar_secondary)".freeze
  BOTTOM_BAR = "nav.bottom-0".freeze

  setup do
    tle = create_level(name: "Tle", position: 7)
    link_level_series(level: tle, series: create_series(name: "D"))
    create_drena(name: "Abidjan 1")
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")
  def tl(key) = I18n.t("teams.referentials.#{key}")
  def labels(scope, selector) = within(scope) { all(selector).map { it.text.squish } }
  def no_horizontal_scroll? = page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")

  test "RE-01: on a wide screen, the « Configuration » card lists Référentiel then Imports, under the destinations" do
    assert_equal [ tn(:home), tn(:courses), tn(:schools), tn(:dashboard), tn(:announcements) ], labels(MAIN_NAV, "a")
    within("aside") do
      assert_selector "nav#sidebar_secondary[aria-labelledby=sidebar_secondary_title]"
      assert_selector "nav#sidebar_secondary #sidebar_secondary_title"
      assert_selector "nav:not(#sidebar_secondary) + nav#sidebar_secondary"
    end
    # Shown in capitals by CSS: the title is read as written, the name of the second navigation.
    assert_equal tn("sidebar.secondary_label.team"), evaluate_script("document.getElementById('sidebar_secondary_title').textContent").squish
    assert_equal [ tn(:referential), tn(:imports) ], labels("nav#sidebar_secondary", "a")

    within("nav#sidebar_secondary") { click_link tn(:referential) }

    assert_current_path teams_referential_path
    assert_selector "main h1", text: tl("show.title")
    within("nav#sidebar_secondary") do
      assert_selector "a[aria-current=page][href='#{teams_referential_path}']", text: tn(:referential)
      assert_no_selector "a[aria-current=page][href='#{teams_imports_path}']"
    end
    within(MAIN_NAV) { assert_no_selector "a[aria-current=page]" }
    within("#team_referential") { assert_link href: levels_path }
    within("#team_referential_structure") { assert_selector "li#level_tle", text: "D" }
  end

  test "RE-02, AN-22: at 390 px, « Plus » is the sixth case of the bottom bar and opens Référentiel and Imports" do
    with_mobile_viewport do
      within(BOTTOM_BAR) do
        assert_selector "ul > li", count: 6
        assert_equal [ tn(:home), tn(:courses), tn(:schools), tn(:dashboard), tn(:announcements) ],
                     all("ul > li > a").map { it.text.squish }
        assert_selector "button#bottom_bar_more[aria-expanded=false]:not([aria-current])", text: tn("bottom_bar.more")
        assert_selector "#bottom_bar_more_menu", visible: :hidden
      end

      open_more_menu

      # Opened, the menu holds the focus on its first entry (dropdown controller, UDR-0068 « États obligatoires »).
      assert_equal tn(:referential), evaluate_script("document.activeElement.textContent").squish
      within("#bottom_bar_more_menu[role=menu]") do
        assert_equal [ tn(:referential), tn(:imports) ], all("a[role=menuitem]").map { it.text.squish }
        click_link tn(:imports)
      end

      assert_current_path teams_imports_path
      assert_selector "button#bottom_bar_more[aria-current=page]"
      within(BOTTOM_BAR) { assert_no_selector "ul > li > a[aria-current=page]" }

      open_more_menu
      within("#bottom_bar_more_menu") do
        assert_selector "a[role=menuitem][aria-current=page][href='#{teams_imports_path}']", text: tn(:imports)
        click_link tn(:referential)
      end

      assert_current_path teams_referential_path
      assert_selector "main h1", text: tl("show.title")
      assert_selector "button#bottom_bar_more[aria-current=page]"
      assert_selector "#team_referential"
      assert no_horizontal_scroll?, "la page Référentiel défile sur le côté à 390 px"
    end
  end

  private

  def open_more_menu
    find("button#bottom_bar_more").click
    assert_selector "button#bottom_bar_more[aria-expanded=true]"
    assert_selector "#bottom_bar_more_menu[role=menu]", visible: true
  end
end
