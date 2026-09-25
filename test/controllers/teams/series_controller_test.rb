require "test_helper"

# ADR-0034, UDR-0006, UDR-0033: the series of the team — list, modal forms, Turbo Stream writes, HTML fallback.
class Teams::SeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
  end

  def t(key, **) = I18n.t(key, **)

  test "a teacher receives 403 on every action, and nothing is written" do
    series = create_series(name: "D")
    sign_in_as create_teacher

    get series_index_path
    assert_response :forbidden
    get new_series_path
    assert_response :forbidden
    get edit_series_path(series.slug)
    assert_response :forbidden
    assert_no_difference -> { Orm::Series.count } do
      post series_index_path, params: { series: { name: "A" } }, as: :turbo_stream
    end
    assert_response :forbidden
    patch series_path(series.slug), params: { series: { name: "X" } }, as: :turbo_stream
    assert_response :forbidden
    delete series_path(series.slug), as: :turbo_stream
    assert_response :forbidden
    assert_equal "D", series.reload.name
  end

  test "the list shows each series with its code, levels and uses, then the level × series matrix" do
    tle = create_level(name: "Tle", position: 7)
    d = create_series(name: "D")
    create_series(name: "A")
    link_level_series(level: tle, series: d)
    create_classroom(level: tle, series: d)
    sign_in_as @member

    get series_index_path

    assert_response :success
    assert_select "h1", t("teams.series.index.title")
    assert_select "a[data-turbo-frame=modal][href='#{new_series_path}']", text: t("teams.series.index.new")
    assert_select "#series tr", 2
    assert_select "#series tr:first-child", text: /A/
    assert_select "#series_d", text: /Tle/
    assert_select "#series_d a[data-turbo-frame=modal][href='#{edit_series_path('d')}']"
    assert_select "#series_d form[action='#{series_path('d')}'] input[name=_method][value=delete]", 1
    assert_select "#series_empty", 0
    assert_select "#level_series_matrix th[scope=row]", text: "Tle"
    assert_select "#level_series_tle_d button[aria-pressed=true]"
    assert_select "#level_series_tle_d form[action='#{level_series_path('tle', 'd')}']"
    assert_select "#level_series_tle_a button[aria-pressed=false]"
    assert_select "#level_series_tle_a form[action='#{level_series_index_path('tle')}'] input[name=series_slug][value=a]"
  end

  test "an empty referential says so, in the list and in the matrix" do
    sign_in_as @member

    get series_index_path

    assert_select "#series tr", 0
    assert_select "#series_empty", text: /#{t("teams.series.index.empty_title")}/
    assert_select "#level_series_matrix", text: /#{t("teams.series.matrix.empty")}/
  end

  test "the new form opens in the modal frame" do
    sign_in_as @member

    get new_series_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog form#series-form[action='#{series_index_path}']"
    assert_select "input[name='series[name]'][maxlength='10'][required]"
    assert_select "button[type=submit][form=series-form]", text: t("teams.series.new.submit")
  end

  test "a created series answers in Turbo Stream: toast, row appended, matrix replaced, empty state removed" do
    create_level(name: "Tle", position: 7)
    sign_in_as @member

    post series_index_path, params: { series: { name: " D " } }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal [ "d", "D" ], Orm::Series.sole.then { [ it.slug, it.name ] }
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{t("teams.series.create.created", name: "D")}/
    assert_select "turbo-stream[action=remove][target=series_empty]"
    assert_select "turbo-stream[action=append][target=series] tr#series_d"
    assert_select "turbo-stream[action=replace][target=level_series_matrix] #level_series_tle_d button[aria-pressed=false]"
    assert_equal "taxonomy.changed", Orm::AuditEvent.sole.action
  end

  test "an invalid or taken name reopens the modal in 422 with its error" do
    create_series(name: "C")
    sign_in_as @member

    post series_index_path, params: { series: { name: "" } }
    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal #series_name_error", text: t("activemodel.errors.models.dtos/catalog/series_input.attributes.name.blank")

    post series_index_path, params: { series: { name: "C" } }
    assert_response :unprocessable_entity
    assert_select "#series_name_error", text: t("activemodel.errors.models.dtos/catalog/series_input.attributes.name.taken")
    assert_select "input[name='series[name]'][value=C]"
    assert_equal 1, Orm::Series.count
  end

  test "without Turbo, a created series leads back to the list" do
    sign_in_as @member

    post series_index_path, params: { series: { name: "D" } }

    assert_redirected_to series_index_path
    assert_equal t("teams.series.create.created", name: "D"), flash[:notice]
  end

  test "the edit form is prefilled; an unknown series is not found" do
    create_series(name: "D")
    sign_in_as @member

    get edit_series_path("d"), headers: { "Turbo-Frame" => "modal" }
    assert_response :success
    assert_select "turbo-frame#modal form#series-form[action='#{series_path('d')}'] input[name=_method][value=patch]"
    assert_select "input[name='series[name]'][value=D]"

    get edit_series_path("inconnue")
    assert_response :not_found
  end

  test "a renamed series keeps its slug, and answers in Turbo Stream with its row and the matrix" do
    create_series(name: "D")
    sign_in_as @member

    patch series_path("d"), params: { series: { name: "Série D" } }, as: :turbo_stream

    assert_response :success
    assert_equal [ "d", "Série D" ], Orm::Series.sole.then { [ it.slug, it.name ] }
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{t("teams.series.update.updated", name: "Série D")}/
    assert_select "turbo-stream[action=replace][target=series_d] tr#series_d", text: /Série D/
    assert_select "turbo-stream[action=replace][target=level_series_matrix]"
  end

  test "a blank name on update is a 422 in the modal, never a 500; unknown series is 404; HTML falls back to the list" do
    create_series(name: "D")
    sign_in_as @member

    patch series_path("d"), params: { series: { name: " " } }
    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal form#series-form #series_name_error"

    patch series_path("inconnue"), params: { series: { name: "X" } }
    assert_response :not_found

    patch series_path("d"), params: { series: { name: "Série D" } }
    assert_redirected_to series_index_path
    assert_equal t("teams.series.update.updated", name: "Série D"), flash[:notice]
  end

  test "a blank series is deleted in Turbo Stream: toast, row removed, matrix replaced" do
    create_series(name: "D")
    sign_in_as @member

    delete series_path("d"), as: :turbo_stream

    assert_response :success
    assert_equal 0, Orm::Series.count
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{t("teams.series.destroy.deleted", name: "D")}/
    assert_select "turbo-stream[action=remove][target=series_d]"
    assert_select "turbo-stream[action=replace][target=level_series_matrix]"
  end

  test "a series in use is kept: 422, error toast with the reason, row re-rendered" do
    link_level_series(level: create_level(name: "Tle", position: 7), series: create_series(name: "D"))
    sign_in_as @member

    delete series_path("d"), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal 1, Orm::Series.count
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(t("teams.series.destroy.referenced", name: "D"))}/
    assert_select "turbo-stream[action=replace][target=series_d] tr#series_d"
    assert_select "turbo-stream[action=remove]", 0
  end

  test "without Turbo, deleting leads back to the list with a notice or the refusal; unknown series is 404" do
    create_series(name: "A")
    link_level_series(level: create_level, series: create_series(name: "D"))
    sign_in_as @member

    delete series_path("a")
    assert_redirected_to series_index_path
    assert_equal t("teams.series.destroy.deleted", name: "A"), flash[:notice]

    delete series_path("d")
    assert_redirected_to series_index_path
    assert_equal t("teams.series.destroy.referenced", name: "D"), flash[:alert]

    delete series_path("inconnue"), as: :turbo_stream
    assert_response :not_found
  end
end
