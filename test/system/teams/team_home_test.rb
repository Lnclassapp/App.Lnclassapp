require "application_system_test_case"

# TR-09, CA-25 (UDR-0018): a team member signs in for real, lands on the team home, reads its counts and its referential,
# sees the recent content load in its lazy frame, and opens « Nouveau cours » in the modal. The old feed read an Orm
# constant that had disappeared.
class Teams::TeamHomeTest < ApplicationSystemTestCase
  setup do
    drena = create_drena(name: "Abidjan 1")
    tle = create_level(name: "Tle", position: 7)
    link_level_series(level: tle, series: create_series(name: "D"))
    school = create_school(drena:, name: "Lycée Classique d'Abidjan")
    create_classroom(school:, level: tle, name: "Tle D 1")
    create_material(name: "SVT", category: "science")
    create_course(name: "Génétique et évolution", status: "draft", level: tle)
  end

  def tl(key, **) = I18n.t("teams.homes.#{key}", **)
  def figure(key, count) = "#{count} #{tl(key, count:)}"

  test "the team member reads the counts and the referential, then opens a new course in the modal" do
    sign_in_as create_team_member(first_name: "Aya")

    assert_current_path team_home_path
    assert_selector "h1", text: tl("show.greeting", name: "Aya")
    within("#team_home_regions") do
      assert_text figure("show.drenas", 1), normalize_ws: true
      assert_text figure("show.schools", 1), normalize_ws: true
      assert_text figure("show.classrooms", 1), normalize_ws: true
    end
    within("#team_home_referential") do
      assert_link href: levels_path, text: figure("referential.levels", 1), normalize_ws: true
      assert_link href: series_index_path, text: figure("referential.series", 1), normalize_ws: true
      assert_selector "li#level_tle", text: "D"
    end
    within("#team_home_recent_courses") { assert_link "Génétique et évolution" }

    assert_no_page_reload do
      within("#team_home_shortcuts") { click_link tl("shortcuts.new_course") }
      assert_selector "turbo-frame#modal dialog[open] form#course-form"
      assert_current_path team_home_path
    end
  end
end
