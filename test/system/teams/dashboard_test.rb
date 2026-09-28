require "application_system_test_case"

# TR-10, TR-11, TR-12 (UDR-0049): the team opens « Pilotage » from its navigation, reads the figures, narrows them to a
# DRENA and finds a student, on a desktop then on a 390 px phone, without the page scrolling sideways.
class Teams::DashboardTest < ApplicationSystemTestCase
  setup do
    tle = create_level(name: "Tle", position: 7)
    abidjan = create_drena(name: "Abidjan 1")
    bouake = create_drena(name: "Bouaké")
    classic = create_school(drena: abidjan, name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: classic, level: tle, name: "Tle D 1")
    create_teacher(school: classic, classrooms: [ @classroom ], first_name: "Yao", last_name: "Kouadio")
    @aya = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
    create_exercise_session(student: @aya, status: "completed", score_percent: 80)
    create_student(classroom: create_classroom(school: create_school(drena: bouake), level: tle), first_name: "Moussa")
    @member = create_team_member(first_name: "Awa")
  end

  def tl(key, **) = I18n.t("teams.dashboards.#{key}", **)

  test "on a desktop, the team opens the dashboard, filters by DRENA and finds a student" do
    sign_in_as @member

    within("aside nav") { click_link I18n.t("shared.navigation.dashboard") }

    assert_dashboard_journey(nav: "aside nav")
  end

  test "on a 390 px phone, the same journey from the bottom bar, without horizontal scroll" do
    sign_in_as @member

    with_mobile_viewport do
      within("nav.bottom-0") { click_link I18n.t("shared.navigation.dashboard") }

      assert_dashboard_journey(nav: "nav.bottom-0")
      assert_no_horizontal_scroll
    end
  end

  private

  def assert_dashboard_journey(nav:)
    assert_current_path team_dashboard_path
    within(nav) { assert_selector "a[aria-current=page]", text: I18n.t("shared.navigation.dashboard") }
    assert_selector "h1", text: tl("show.title")
    assert_selector "#figure_students", text: /\A2\s+#{tl('key_figures.students', count: 2)}\z/
    assert_selector "#team_dashboard_drenas tbody tr", count: 2
    assert_no_horizontal_scroll

    click_link tl("periods.30d")
    assert_selector "#team_dashboard_filters a[aria-current=true]", text: tl("periods.30d")

    select "Abidjan 1", from: tl("filters.drena_label")
    click_button tl("filters.submit")

    assert_selector "#team_dashboard_scope", text: "Abidjan 1"
    assert_selector "#figure_students", text: /\A1\s+#{tl('key_figures.students', count: 1)}\z/
    assert_selector "#team_dashboard_drenas tbody tr", count: 1
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

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
