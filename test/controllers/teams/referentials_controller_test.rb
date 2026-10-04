require "test_helper"

# RE-03, RE-04 (UDR-0068 §3.4): the referential leaves the team home for its own page, reached from the « Configuration »
# card and the « Plus » menu. Its tiles and its school structure are those the home carried (CA-25, BC-10), read with no
# cache; the page is the team's alone.
class Teams::ReferentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
  end

  def tl(key, **) = I18n.t("teams.referentials.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  # A figure reads as its number, then its label: « 2 niveaux ».
  def figure(key, count) = including("#{count} #{tl("summary.#{key}", count:)}")

  test "RE-04: a student, a teacher and a school admin receive 403" do
    [ create_student, create_teacher, create_school_admin ].each do |user|
      sign_in_as user

      get teams_referential_path

      assert_response :forbidden
      sign_out
    end
  end

  test "a team member whose second factor is not verified is sent to the second factor" do
    post session_path, params: { session: { contact: @member.contact, pin: "2468" } }

    get teams_referential_path

    assert_redirected_to new_identity_second_factor_path
  end

  test "RE-03: the page is « Référentiel », titled by its header, and its entry of the « Configuration » card is current" do
    sign_in_as @member

    get teams_referential_path

    assert_response :success
    assert_select "title", "#{tl('show.page_title')} · Équipe · Lnclass"
    assert_select "main h1", tl("show.title")
    assert_select "main p", tl("show.subtitle")
    assert_select "nav#sidebar_secondary a[aria-current=page][href='#{teams_referential_path}']", text: I18n.t("shared.navigation.referential")
    assert_select "nav#sidebar_secondary a[aria-current=page]", 1
    assert_select "aside nav:not(#sidebar_secondary) a[aria-current=page]", 0
    assert_select "button#bottom_bar_more[aria-current=page]"
    assert_select "#bottom_bar_more_menu a[role=menuitem][aria-current=page][href='#{teams_referential_path}']"
  end

  test "RE-03: the tiles show the counts of DRENA, levels, series and materials, each leading to its screen" do
    create_drena
    tle = create_level(name: "Tle", position: 7)
    create_level(name: "6ème", position: 1)
    link_level_series(level: tle, series: create_series(name: "D"))
    create_series(name: "A1")
    3.times { create_material }
    sign_in_as @member

    get teams_referential_path

    assert_select "#team_referential" do
      # The page header carries the title: the card of the tiles has none.
      assert_select "h2", 0
      { drenas_path => figure("drenas", 1), levels_path => figure("levels", 2),
        series_index_path => figure("series", 2), materials_path => figure("materials", 3) }
        .each { |path, label| assert_select "a[href='#{path}']", text: label }
      assert_select "a", text: including(tl("summary.manage")), count: 5
    end
  end

  test "RE-03: the school structure is its own card, each level with its series, or « Sans série »" do
    tle = create_level(name: "Tle", position: 7)
    create_level(name: "6ème", position: 1)
    link_level_series(level: tle, series: create_series(name: "D"))
    sign_in_as @member

    get teams_referential_path

    assert_select "#team_referential li#level_tle", 0
    assert_select "#team_referential_structure" do
      assert_select "h2", tl("summary.structure_title")
      assert_select "li#level_6eme", text: including("6ème") do
        assert_select "*", text: tl("summary.no_series")
      end
      assert_select "li#level_tle", text: including("Tle") do
        assert_select "*", text: "D"
      end
    end
  end

  test "BC-10: the referential leads to the barème of the classrooms, with the total of a public lycée" do
    seed_referential
    sign_in_as @member

    get teams_referential_path

    assert_select "#team_referential a[href='#{classroom_plan_path}']", text: figure("classroom_plan", 77)
  end

  test "the counts follow the last creation, with no cache" do
    sign_in_as @member
    get teams_referential_path
    assert_select "#team_referential a[href='#{levels_path}']", text: figure("levels", 0)

    create_level

    get teams_referential_path
    assert_select "#team_referential a[href='#{levels_path}']", text: figure("levels", 1)
  end

  test "an empty referential says so and still leads to each screen" do
    sign_in_as @member

    get teams_referential_path

    assert_select "#team_referential" do
      [ drenas_path, levels_path, series_index_path, materials_path, classroom_plan_path ].each { assert_select "a[href='#{it}']" }
    end
    assert_select "#team_referential_structure", text: including(tl("summary.levels_empty"))
  end
end
