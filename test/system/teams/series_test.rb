require "application_system_test_case"

# CA-19, CA-24, UDR-0033: the team creates a series, opens it to the Tle in the matrix, and cannot untick a pair
# that a classroom uses — every write without a page reload.
class Teams::SeriesTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/import_flow_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    @tle = create_level(name: "Tle", position: 7)
    @first = create_level(name: "1ère", position: 6)
    @c = create_series(name: "C")
    link_level_series(level: @first, series: @c)
    create_classroom(level: @first, series: @c)
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit series_index_path
  end

  def t(key, **) = I18n.t(key, **)

  test "create a series, open it to the Tle, and fail to untick a pair in use" do
    assert_no_page_reload do
      click_on t("teams.series.index.new")
      within "turbo-frame#modal dialog[open]" do
        fill_in "series[name]", with: "   "
        click_on t("teams.series.new.submit")
        assert_selector "#series_name_error", text: t("activemodel.errors.models.dtos/catalog/series_input.attributes.name.blank")
        fill_in "series[name]", with: "D"
        click_on t("teams.series.new.submit")
      end
      assert_toast t("teams.series.create.created", name: "D")
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_selector "#series tr#series_d", text: "D"

      find("#level_series_tle_d button[aria-pressed=false]").click
      assert_toast t("teams.level_series.create.done", level: "Tle", series: "D")
      assert_selector "#level_series_tle_d button[aria-pressed=true]"

      find("#level_series_1ere_c button[aria-pressed=true]").click
      assert_toast t("teams.level_series.destroy.refused", level: "1ère", series: "C")
      assert_selector "#level_series_1ere_c button[aria-pressed=true]"
    end
    assert Orm::LevelSeries.exists?(level: @tle, series: Orm::Series.find_by!(slug: "d"))
    assert Orm::LevelSeries.exists?(level: @first, series: @c)
  end

  test "rename a series, delete a blank one, and fail to delete one in use" do
    create_series(name: "A")
    visit series_index_path

    assert_no_page_reload do
      within("#series_a") { click_on t("teams.series.series_row.edit") }
      within "turbo-frame#modal dialog[open]" do
        fill_in "series[name]", with: "A bis"
        click_on t("teams.series.edit.submit")
      end
      assert_toast t("teams.series.update.updated", name: "A bis")
      assert_selector "#series_a", text: "A bis"
      assert_selector "#level_series_matrix th", text: "A bis"

      within("#series_a") { click_on t("teams.series.series_row.delete") }
      within("#delete-series-a") { click_on t("teams.series.series_row.confirm") }
      assert_toast t("teams.series.destroy.deleted", name: "A bis")
      assert_no_selector "#series_a"

      within("#series_c") { click_on t("teams.series.series_row.delete") }
      within("#delete-series-c") { click_on t("teams.series.series_row.confirm") }
      assert_toast t("teams.series.destroy.referenced", name: "C")
      assert_selector "#series_c"
    end
  end

  test "on a phone, the tables scroll inside their frame, never the page" do
    create_series(name: "A")
    link_level_series(level: @tle, series: Orm::Series.find_by!(slug: "a"))
    visit series_index_path

    with_mobile_viewport do
      assert_selector "#level_series_matrix"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"
    end
  end
end
