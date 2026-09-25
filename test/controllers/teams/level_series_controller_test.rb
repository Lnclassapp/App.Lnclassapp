require "test_helper"

# ADR-0034, ADR-0036, UDR-0033: a pair of the level × series matrix is ticked or unticked in Turbo Stream.
class Teams::LevelSeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @tle = create_level(name: "Tle", position: 7)
    @d = create_series(name: "D")
  end

  def t(key, **) = I18n.t(key, level: "Tle", series: "D", **)

  test "a teacher receives 403, and nothing is written" do
    sign_in_as create_teacher

    post level_series_index_path("tle"), params: { series_slug: "d" }, as: :turbo_stream
    assert_response :forbidden
    delete level_series_path("tle", "d"), as: :turbo_stream
    assert_response :forbidden
    assert_equal 0, Orm::LevelSeries.count
  end

  test "ticking a pair links it: its cell is replaced, with a toast" do
    sign_in_as @member

    post level_series_index_path("tle"), params: { series_slug: "d" }, as: :turbo_stream

    assert_response :success
    assert Orm::LevelSeries.exists?(level: @tle, series: @d)
    assert_select "turbo-stream[action=replace][target=level_series_tle_d] button[aria-pressed=true]"
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{t("teams.level_series.create.done")}/
    assert_equal "taxonomy.changed", Orm::AuditEvent.sole.action
  end

  test "a pair already linked is refused in 422, its cell resynchronised" do
    link_level_series(level: @tle, series: @d)
    sign_in_as @member

    post level_series_index_path("tle"), params: { series_slug: "d" }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{t("teams.level_series.create.refused")}/
    assert_select "turbo-stream[action=replace][target=level_series_tle_d] button[aria-pressed=true]"
  end

  test "unticking an unused pair unlinks it" do
    link_level_series(level: @tle, series: @d)
    sign_in_as @member

    delete level_series_path("tle", "d"), as: :turbo_stream

    assert_response :success
    assert_equal 0, Orm::LevelSeries.count
    assert_select "turbo-stream[action=replace][target=level_series_tle_d] button[aria-pressed=false]"
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{t("teams.level_series.destroy.done")}/
  end

  test "unticking a pair used by a classroom or a course is refused with the reason, never silently" do
    link_level_series(level: @tle, series: @d)
    create_course(level: @tle, series: @d)
    sign_in_as @member

    delete level_series_path("tle", "d"), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal 1, Orm::LevelSeries.count
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{t("teams.level_series.destroy.refused")}/
    assert_select "turbo-stream[action=replace][target=level_series_tle_d] button[aria-pressed=true]"
  end

  test "without Turbo, both writes lead back to the list, with a notice or the refusal" do
    create_classroom(level: @tle, series: @d)
    sign_in_as @member

    post level_series_index_path("tle"), params: { series_slug: "d" }
    assert_redirected_to series_index_path
    assert_equal t("teams.level_series.create.done"), flash[:notice]

    delete level_series_path("tle", "d")
    assert_redirected_to series_index_path
    assert_equal t("teams.level_series.destroy.refused"), flash[:alert]
  end

  test "an unknown level or series is not found" do
    sign_in_as @member

    post level_series_index_path("inconnu"), params: { series_slug: "d" }, as: :turbo_stream
    assert_response :not_found
    delete level_series_path("tle", "inconnue"), as: :turbo_stream
    assert_response :not_found
  end
end
