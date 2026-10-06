require "application_system_test_case"

# TR-10, TR-11, TR-12 (UDR-0049): the team opens « Pilotage » from its navigation, reads the figures, narrows them to a
# DRENA and finds a student, on a desktop then on a 390 px phone, without the page scrolling sideways.
# RE-06, RE-07 (UDR-0068 §3.5, §3.6): the DRENA table filters its rows in the browser, and a DRENA name opens the
# establishments of the DRENA, period kept, searchable by name.
class Teams::DashboardTest < ApplicationSystemTestCase
  setup do
    tle = create_level(name: "Tle", position: 7)
    @abidjan = create_drena(name: "Abidjan 1")
    create_drena(name: "Abidjan 2")
    bouake = create_drena(name: "Bouaké")
    classic = create_school(drena: @abidjan, name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: classic, level: tle, name: "Tle D 1")
    create_teacher(school: classic, classrooms: [ @classroom ], first_name: "Yao", last_name: "Kouadio")
    @aya = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
    create_exercise_session(student: @aya, status: "completed", score_percent: 80)
    create_school(drena: @abidjan, name: "Lycée Moderne de Cocody")
    create_student(classroom: create_classroom(school: create_school(drena: bouake), level: tle), first_name: "Moussa")
    @member = create_team_member(first_name: "Awa")
  end

  def tl(key, **) = I18n.t("teams.dashboards.#{key}", **)

  test "on a desktop, the team opens the dashboard, filters by DRENA and finds a student" do
    sign_in_as @member
    # UDR-0068 §3.2: the sidebar of the team holds two nav, the destinations then « Configuration ».
    destinations = "aside nav[aria-label='#{I18n.t('shared.navigation.sidebar.label')}']"

    within(destinations) { click_link I18n.t("shared.navigation.dashboard") }

    assert_dashboard_journey(nav: destinations)
  end

  test "on a 390 px phone, the same journey from the bottom bar, without horizontal scroll" do
    sign_in_as @member

    with_mobile_viewport do
      within("nav.bottom-0") { click_link I18n.t("shared.navigation.dashboard") }

      assert_dashboard_journey(nav: "nav.bottom-0")
      assert_no_horizontal_scroll
    end
  end

  test "RE-06, RE-07: the team narrows the DRENA table, then reads and searches the establishments of Abidjan 1" do
    sign_in_as @member
    visit team_dashboard_path(period: "30d")

    assert_drena_filter
    assert_establishments_of_abidjan
  end

  test "RE-06, RE-07 on a 390 px phone: the filter and the establishments, without horizontal scroll" do
    sign_in_as @member

    with_mobile_viewport do
      visit team_dashboard_path(period: "30d")

      assert_drena_filter
      assert_no_horizontal_scroll
      assert_establishments_of_abidjan
      assert_no_horizontal_scroll
    end
  end

  private

  def assert_dashboard_journey(nav:)
    assert_current_path team_dashboard_path
    within(nav) { assert_selector "a[aria-current=page]", text: I18n.t("shared.navigation.dashboard") }
    assert_selector "h1", text: tl("show.title")
    assert_selector "#figure_students", text: /\A2\s+#{tl('key_figures.students', count: 2)}\z/
    assert_selector "#team_dashboard_drenas tbody tr", count: 3
    assert_no_horizontal_scroll

    click_link tl("periods.30d")
    assert_selector "#team_dashboard_filters a[aria-current=true]", text: tl("periods.30d")

    # UDR-0054 §3.9: the DRENA applies on change; « Filtrer » only shows without JavaScript.
    assert_no_button tl("filters.submit")
    select "Abidjan 1", from: tl("filters.drena_label")

    assert_selector "#team_dashboard_scope", text: "Abidjan 1"
    assert_selector "#figure_students", text: /\A1\s+#{tl('key_figures.students', count: 1)}\z/
    assert_no_selector "#team_dashboard_drenas"
    assert_selector "#team_dashboard_schools tbody tr", count: 2
    assert_selector "#team_dashboard_filters a[aria-current=true]", text: tl("periods.30d")

    fill_in tl("search.label"), with: "kouassi"
    click_button tl("search.submit")

    within("#team_dashboard_search") do
      assert_selector "#account_#{@aya.public_id}", text: "Aya Kouassi"
      assert_selector "#account_#{@aya.public_id}", text: "Tle D 1"
      assert_no_text @aya.contact
    end
    assert_selector "#team_dashboard_scope", text: "Abidjan 1"
    assert_current_path(/q=kouassi/)
  end

  # RE-06: « abidj » keeps the two Abidjan rows, « zzz » shows the empty message, an empty field shows every row again.
  def assert_drena_filter
    rows = "#team_dashboard_drenas tbody tr"
    assert_selector rows, count: 3

    fill_in tl("drenas.filter_label"), with: "abidj"

    assert_selector rows, count: 2
    assert_selector rows, text: "Abidjan 1"
    assert_selector rows, text: "Abidjan 2"
    assert_no_selector rows, text: "Bouaké"
    assert_selector "#team_dashboard_drenas [data-table-filter-target=status]", text: tl("drenas.filter_status", count: 2),
                                                                               visible: :all
    assert_no_selector "#drena_filter_empty"

    fill_in tl("drenas.filter_label"), with: "zzz"

    assert_no_selector rows
    assert_selector "#drena_filter_empty", text: tl("drenas.filter_empty")

    fill_in tl("drenas.filter_label"), with: "", fill_options: { clear: :backspace }

    assert_selector rows, count: 3
    assert_no_selector "#drena_filter_empty"

    fill_in tl("drenas.filter_label"), with: "abidj"
    assert_selector rows, count: 2
  end

  # RE-07, RE-10: the name opens the establishments, period kept; the search reads them by name.
  def assert_establishments_of_abidjan
    within("#team_dashboard_drenas") { click_link "Abidjan 1" }

    assert_current_path team_dashboard_path(period: "30d", drena: @abidjan.public_id)
    assert_no_selector "#team_dashboard_drenas"
    within("#team_dashboard_schools") do
      assert_selector "h2", text: tl("schools.title")
      assert_selector "tbody tr", count: 2
      assert_selector "tbody tr:first-child th", text: "Lycée Classique d'Abidjan"
      assert_selector "tbody tr:first-child td", count: 4

      fill_in tl("schools.search_label"), with: "cocody"
      click_button tl("schools.submit")
    end

    assert_current_path(/school_q=cocody/)
    assert_current_path(/period=30d/)
    within("#team_dashboard_schools") do
      assert_selector "tbody tr", count: 1
      assert_selector "tbody tr th", text: "Lycée Moderne de Cocody"
      click_link tl("schools.clear")
    end
    assert_current_path team_dashboard_path(period: "30d", drena: @abidjan.public_id)
    assert_selector "#team_dashboard_schools tbody tr", count: 2
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
