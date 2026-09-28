require "test_helper"

# TR-10, TR-11, TR-12 (UDR-0049, ADR-0062): the team dashboard. The old « Control Center » had no test and broke on a
# renamed method; this page is read by a query whose every indicator is tested, and served to the team only.
class Teams::DashboardsControllerTest < ActionDispatch::IntegrationTest
  SEARCH_FRAME = "team_dashboard_search".freeze

  setup do
    @member = create_team_member
  end

  def tl(key, **) = I18n.t("teams.dashboards.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  # A figure reads as its number, then its label: « 2 élèves actifs ».
  def figure(key, count) = including("#{count} #{tl("key_figures.#{key}", count:)}")

  test "a teacher, a student and a school admin receive 403; a visitor goes to the sign-in" do
    [ create_teacher, create_student, create_school_admin ].each do |user|
      sign_in_as user

      get team_dashboard_path
      assert_response :forbidden
      get team_dashboard_path(q: "aya"), headers: { "Turbo-Frame" => SEARCH_FRAME }
      assert_response :forbidden
      sign_out
    end

    get team_dashboard_path

    assert_redirected_to new_session_path
  end

  test "a team member whose second factor is not verified is sent to the second factor" do
    post session_path, params: { session: { contact: @member.contact, pin: "2468" } }

    get team_dashboard_path

    assert_redirected_to new_identity_second_factor_path
  end

  test "every team sub-role reads the dashboard, marked current in the navigation" do
    %w[admin content field].each do |team_role|
      sign_in_as create_team_member(team_role:)

      get team_dashboard_path

      assert_response :success
      assert_select "h1", text: tl("show.title")
      assert_select "aside nav a[aria-current=page][href='#{team_dashboard_path}']"
      sign_out
    end
  end

  test "the key figures of the period and of the moment, national by default over 7 days" do
    classroom = create_classroom(level: create_level(name: "Tle", position: 7))
    student = create_student(classroom:)
    create_exercise_session(student:, status: "completed", score_percent: 80)
    sign_in_as @member

    get team_dashboard_path

    assert_select "#team_dashboard_scope", text: including(tl("show.national"))
    assert_select "#team_dashboard_scope", text: including(tl("period_scopes.7d"))
    assert_select "#team_dashboard_period" do
      assert_select "#figure_active_students", text: figure("active_students", 1)
      assert_select "#figure_completed_sessions", text: figure("completed_sessions", 1)
      assert_select "#figure_completed_sessions", text: including(tl("key_figures.success_rate", rate: 80))
    end
    assert_select "#team_dashboard_now" do
      assert_select "#figure_students", text: figure("students", 1)
      assert_select "#figure_classrooms", text: figure("classrooms", 1)
      assert_select "#figure_schools", text: figure("schools", 1)
      assert_select "#team_dashboard_coverage li", 3
    end
    assert_select "#team_dashboard_levels #level_share_tle", text: including(tl("levels.share", count: 1, percent: 100))
    assert_select "#team_dashboard_levels #level_share_tle [aria-hidden=true] .w-full"
    assert_select "#team_dashboard_drenas table caption", text: tl("drenas.caption", period: tl("period_scopes.7d"))
    assert_select "#team_dashboard_drenas th[scope=row]", 1
    assert_select "#team_dashboard_signups #signup_#{student.public_id}", text: including(Entities::Identity::Contact.mask(student.contact))
    assert_no_match student.contact, response.body
  end

  test "an empty base: zeros, no success rate and the empty states" do
    sign_in_as @member

    get team_dashboard_path

    assert_select "#figure_active_students", text: figure("active_students", 0)
    assert_select "#figure_completed_sessions", text: including(tl("key_figures.no_success_rate"))
    assert_select "#team_dashboard_levels", text: including(tl("levels.empty_title"))
    assert_select "#team_dashboard_drenas", text: including(tl("drenas.empty_title"))
    assert_select "#team_dashboard_drenas table", 0
  end

  test "the period links keep the DRENA, and the current one is marked" do
    drena = create_drena(name: "Abidjan 1")
    sign_in_as @member

    get team_dashboard_path(period: "30d", drena: drena.public_id)

    assert_select "#team_dashboard_filters nav a[aria-current=true]", text: tl("periods.30d")
    assert_select "#team_dashboard_filters nav a[href='#{team_dashboard_path(period: 'year', drena: drena.public_id)}']",
                  text: tl("periods.year")
    assert_select "#team_dashboard_scope", text: including(tl("period_scopes.30d"))
  end

  test "the DRENA filter narrows the page, is selected in the list and can be cleared" do
    here = create_drena(name: "Abidjan 1")
    create_drena(name: "Bouaké")
    sign_in_as @member

    get team_dashboard_path(drena: here.public_id)

    assert_select "#dashboard_drena option[selected][value='#{here.public_id}']", text: "Abidjan 1"
    assert_select "#dashboard_drena option", 3
    assert_select "#team_dashboard_filters input[type=hidden][name=period][value='7d']"
    assert_select "#team_dashboard_scope", text: including("Abidjan 1")
    assert_select "#team_dashboard_drenas th[scope=row]", 1
    assert_select "#figure_team", text: including(tl("key_figures.team_without_drena"))
    assert_select "#team_dashboard_levels #students_without_classroom", 0
    assert_select "#team_dashboard_filters a[href='#{team_dashboard_path(period: '7d')}']", text: tl("filters.clear")
  end

  test "an unknown period or DRENA gives the national view over 7 days" do
    sign_in_as @member

    get team_dashboard_path(period: "365d", drena: "inconnue")

    assert_response :success
    assert_select "#team_dashboard_filters nav a[aria-current=true]", text: tl("periods.7d")
    assert_select "#dashboard_drena option[selected]", 0
    assert_select "#team_dashboard_scope", text: including(tl("show.national"))
  end

  # TR-11: the search lives in its own frame; a frame request renders only the results, without the indicators.
  test "a search served to its frame renders only the results, masked, with role, school and classroom" do
    classroom = create_classroom(school: create_school(name: "Lycée Classique d'Abidjan"), name: "Tle D 1")
    aya = create_student(classroom:, first_name: "Aya", last_name: "Kouassi")
    sign_in_as @member

    get team_dashboard_path(q: "kouassi"), headers: { "Turbo-Frame" => SEARCH_FRAME }

    assert_response :success
    assert_select "turbo-frame##{SEARCH_FRAME}" do
      assert_select "#search_total", text: tl("search_results.total", count: 1)
      assert_select "#account_#{aya.public_id}", text: including("Aya Kouassi")
      assert_select "#account_#{aya.public_id}", text: including("Lycée Classique d'Abidjan · Tle D 1")
      assert_select "#account_#{aya.public_id}", text: including(Entities::Identity::Contact.mask(aya.contact))
    end
    assert_select "#team_dashboard_period", 0
    assert_no_match aya.contact, response.body
  end

  test "the full page renders the search too, with the filters kept in hidden fields" do
    drena = create_drena
    create_teacher(first_name: "Yao", last_name: "Kouadio", classrooms: [ create_classroom, create_classroom ])
    sign_in_as @member

    get team_dashboard_path(q: "kouadio", period: "30d", drena: drena.public_id)

    assert_select "#team_dashboard_search_card form[data-turbo-frame=#{SEARCH_FRAME}][data-turbo-action=advance]" do
      assert_select "input[type=hidden][name=period][value='30d']"
      assert_select "input[type=hidden][name=drena][value='#{drena.public_id}']"
      assert_select "input[name=q][value=kouadio]"
    end
    assert_select "turbo-frame##{SEARCH_FRAME} li", text: including(tl("search_results.classrooms", count: 2))
  end

  test "the search states: prompt, too short, nothing found, and pages of 20" do
    21.times { |index| create_student(last_name: format("Zadi %02d", index)) }
    sign_in_as @member
    frame = ->(q) { get(team_dashboard_path(q:), headers: { "Turbo-Frame" => SEARCH_FRAME }) }

    get team_dashboard_path
    assert_select "turbo-frame##{SEARCH_FRAME}", text: including(tl("search_results.prompt"))
    frame.call("z")
    assert_select "turbo-frame##{SEARCH_FRAME}", text: including(tl("search_results.too_short"))
    frame.call("personne")
    assert_select "turbo-frame##{SEARCH_FRAME}", text: including(tl("search_results.empty_title"))
    frame.call("zadi")
    assert_select "#search_results li", 20
    assert_select "turbo-frame##{SEARCH_FRAME} a[href*='page=2'][href*='q=zadi']"
  end

  # Challenger of PR #51: a malformed query string never gives a 500. A non-scalar value, or text holding a null byte,
  # is an invalid value: the parameter is ignored (national view, 7 days, no search, page 1).
  test "a malformed parameter is ignored: array or hash page, null byte in the search, the DRENA or the period" do
    create_student(first_name: "Aya", last_name: "Kouassi")
    sign_in_as @member
    frame = { "Turbo-Frame" => SEARCH_FRAME }

    [ "q=koua&page[]=2", "q=koua&page[a]=1" ].each do |query|
      get "#{team_dashboard_path}?#{query}", headers: frame
      assert_response :success, query
      assert_select "#search_total", text: tl("search_results.total", count: 1)
    end

    get "#{team_dashboard_path}?q=ko%00ua", headers: frame
    assert_response :success
    assert_select "turbo-frame##{SEARCH_FRAME}", text: including(tl("search_results.prompt"))

    [ "q=ko%00ua", "drena=x%00", "period=7d%00", "q[]=koua&drena[a]=x&period[]=30d" ].each do |query|
      get "#{team_dashboard_path}?#{query}"
      assert_response :success, query
      assert_select "#team_dashboard_scope", text: including(tl("show.national"))
      assert_select "#team_dashboard_filters nav a[aria-current=true]", text: tl("periods.7d")
    end
  end

  test "the search pages advance the URL, so a reload keeps the current page" do
    21.times { |index| create_student(last_name: format("Zadi %02d", index)) }
    sign_in_as @member

    get team_dashboard_path(q: "zadi")

    assert_select "turbo-frame##{SEARCH_FRAME}[data-turbo-action=advance] a[href*='page=2']"
  end
end
