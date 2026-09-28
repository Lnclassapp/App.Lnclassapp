require "test_helper"

# BC-01 to BC-05, BC-08, UDR-0045: the barème of the classrooms, read and changed by the team, in a modal, in Turbo Stream.
class Teams::ClassroomPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    seed_referential
  end

  def tl(key, **) = I18n.t("teams.classroom_plans.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def line_params(public_count: "5", private_count: "2") = { classroom_plan_line: { public_count:, private_count: } }
  def entry(level, series = nil, school_type: "public")
    Orm::ClassroomPlanEntry.find_by(school_type:, level: Orm::Level.find_by!(slug: level), series: series && Orm::Series.find_by!(slug: series))
  end

  test "BC-08: a teacher receives 403 on every action, and nothing is written" do
    sign_in_as create_teacher

    get classroom_plan_path
    assert_response :forbidden
    get edit_classroom_plan_line_path("6eme"), headers: { "Turbo-Frame" => "modal" }
    assert_response :forbidden
    patch classroom_plan_line_path("6eme"), params: line_params, as: :turbo_stream
    assert_response :forbidden

    assert_equal 4, entry("6eme").count
    assert_equal 0, Orm::AuditEvent.count
  end

  test "BC-01: one line per level of the first cycle and per linked pair, both counts, the totals and the guard" do
    sign_in_as @member

    get classroom_plan_path

    assert_response :success
    assert_select "h1", tl("show.title")
    assert_select "#classroom-plan-notice", text: including(tl("show.notice"))
    assert_select "#classroom_plan_undefined", text: ""
    assert_select "#classroom_plan_lines tr", 14
    assert_select "#classroom_plan_lines tr:first-child#classroom_plan_line_6eme", text: /6ème\s+—\s+4\s+2/
    assert_select "#classroom_plan_line_tle_d", text: /Tle\s+D\s+6\s+3/
    assert_select "#classroom_plan_line_2nde_a [role=menu] a[role=menuitem][data-turbo-frame=modal][href='#{edit_classroom_plan_line_path('2nde', 'a')}']",
                  text: including(tl("line_row.edit"))
    assert_select "#classroom_plan_line_2nde_a button[aria-label='#{tl('line_row.actions', name: '2nde A')}']"
    { "public_both" => 77, "public_first" => 28, "private_both" => 38, "private_first" => 12 }.each do |key, total|
      assert_select "#classroom_plan_total_#{key}", text: including(total.to_s)
    end
  end

  test "BC-04: an undefined pair is flagged and counted; a zero reads « aucune classe »; a level without series has no menu" do
    link_level_series(level: Orm::Level.find_by!(slug: "tle"), series: Orm::Series.find_by!(slug: "a"))
    Orm::LevelSeries.where(level: Orm::Level.find_by!(slug: "1ere")).delete_all
    entry("2nde", "c").update!(count: 0)
    sign_in_as @member

    get classroom_plan_path

    assert_select "#classroom_plan_line_tle_a [data-plan=undefined]", count: 2, text: including(tl("line_row.undefined"))
    assert_select "#classroom_plan_undefined [role=status]", text: including(tl("undefined.undefined", count: 1))
    assert_select "#classroom_plan_line_2nde_c .sr-only", text: tl("line_row.none")
    assert_select "#classroom_plan_line_1ere", text: including(tl("line_row.no_series"))
    assert_select "#classroom_plan_line_1ere a[href='#{series_index_path}']", text: tl("line_row.link_series")
    assert_select "#classroom_plan_line_1ere [role=menu]", 0
  end

  test "an empty referential says so and leads to the levels" do
    Orm::ClassroomPlanEntry.delete_all
    Orm::LevelSeries.delete_all
    Orm::Level.delete_all
    sign_in_as @member

    get classroom_plan_path

    assert_select "#classroom_plan_empty", text: including(tl("show.empty_title"))
    assert_select "#classroom_plan_empty a[href='#{levels_path}']"
    assert_select "#classroom_plan_lines", 0
    assert_select "#classroom_plan_total_public_both", text: including("0")
  end

  test "the edit form opens in the modal, filled in with both counts, and recalls the guard" do
    sign_in_as @member

    get edit_classroom_plan_line_path("tle", "d"), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#classroom-plan-line-modal form#classroom-plan-line-form[action='#{classroom_plan_line_path('tle', 'd')}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[type=number][name='classroom_plan_line[public_count]'][value='6'][min='0'][max='30']"
      assert_select "input[type=number][name='classroom_plan_line[private_count]'][value='3']"
    end
    assert_select "dialog#classroom-plan-line-modal h2", text: tl("edit.title", name: "Tle D")
    assert_select "dialog#classroom-plan-line-modal", text: including(tl("edit.untouched"))
    assert_select "button[type=submit][form=classroom-plan-line-form]", text: tl("edit.submit")
  end

  test "an undefined line opens with empty fields" do
    link_level_series(level: Orm::Level.find_by!(slug: "tle"), series: Orm::Series.find_by!(slug: "a"))
    sign_in_as @member

    get edit_classroom_plan_line_path("tle", "a"), headers: { "Turbo-Frame" => "modal" }

    assert_select "input[name='classroom_plan_line[public_count]']:not([value])"
  end

  test "BC-02: a change answers in Turbo Stream: toast, the line, the totals and the undefined notice; one audit per changed count" do
    sign_in_as @member

    patch classroom_plan_line_path("6eme"), params: line_params, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("update.updated", name: "6ème"))
    assert_select "turbo-stream[action=replace][target=classroom_plan_line_6eme] tr#classroom_plan_line_6eme", text: /6ème\s+—\s+5\s+2/
    assert_select "turbo-stream[action=replace][target=classroom_plan_totals] #classroom_plan_total_public_both", text: including("78")
    assert_select "turbo-stream[action=replace][target=classroom_plan_undefined]"
    assert_equal [ 5, 2 ], [ entry("6eme").count, entry("6eme", school_type: "private").count ]
    event = Orm::AuditEvent.sole
    assert_equal [ "classroom_plan.changed", @member.id, "Level" ], [ event.action, event.actor_id, event.subject_type ]
    assert_equal({ "school_type" => "public", "level" => "6eme", "series" => nil, "from" => 4, "to" => 5 }, event.metadata)
  end

  test "BC-05: a change never touches the classrooms already created" do
    school = create_school(drena: create_drena(name: "Abidjan 2"), name: "Lycée Moderne")
    kept = Array.new(4) { create_classroom(school:, level: Orm::Level.find_by!(slug: "6eme"), name: "6ème #{it + 1}") }
    sign_in_as @member

    patch classroom_plan_line_path("6eme"), params: line_params(public_count: "1"), as: :turbo_stream

    assert_equal kept.map(&:id).sort, Orm::Classroom.where(school:).ids.sort
    assert_equal kept.map(&:name).sort, Orm::Classroom.where(school:).pluck(:name).sort
  end

  test "BC-03: an invalid count reopens the modal in 422, with its error and the values typed; nothing written" do
    sign_in_as @member

    patch classroom_plan_line_path("tle", "d"), params: line_params(public_count: "31", private_count: "2.5"), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#classroom-plan-line-modal form#classroom-plan-line-form" do
      assert_select "input[name='classroom_plan_line[public_count]'][value='31'][aria-invalid=true]"
      assert_select "input[name='classroom_plan_line[private_count]'][value='2.5'][aria-invalid=true]"
      assert_select "#classroom_plan_line_public_count_error"
    end
    assert_equal 6, entry("tle", "d").count
    assert_equal 0, Orm::AuditEvent.count
  end

  test "an unknown line has no form and cannot be changed" do
    sign_in_as @member

    get edit_classroom_plan_line_path("tle"), headers: { "Turbo-Frame" => "modal" }
    assert_response :not_found
    get edit_classroom_plan_line_path("tle", "a"), headers: { "Turbo-Frame" => "modal" }
    assert_response :not_found
    patch classroom_plan_line_path("inconnu"), params: line_params, as: :turbo_stream
    assert_response :not_found
  end

  test "without Turbo, a change leads back to the barème with a notice" do
    sign_in_as @member

    patch classroom_plan_line_path("tle", "d"), params: line_params

    assert_redirected_to classroom_plan_path
    assert_equal tl("update.updated", name: "Tle D"), flash[:notice]
  end
end
