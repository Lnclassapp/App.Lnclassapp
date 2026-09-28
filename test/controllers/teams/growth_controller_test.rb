require "test_helper"

# CP-16 to CP-18 (ADR-0063, UDR-0050): « Croissance », /teams/growth, for the team only, reached from the team home; no
# navigation entry (UDR-0006: 5 destinations), and /teams/dashboard untouched.
class Teams::GrowthControllerTest < ActionDispatch::IntegrationTest
  SCOPE = "teams.growth.show".freeze

  setup do
    @member = create_team_member(team_role: "content")
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @aya = create_teacher(school: @school, first_name: "Aya", last_name: "Koné")
    create_referral(referrer: @aya)
    2.times { create_referral_share(user: @aya) }
  end

  test "CP-17, CP-18: the page reads k and its decomposition, the metrics, the referrers, the ranking and the requests" do
    create_join_request(school: @school)
    sign_in_as @member

    get teams_growth_path

    assert_response :success
    assert_select "h1", text: I18n.t("#{SCOPE}.title")
    assert_select "nav#growth_periods a[aria-current=page][href='#{teams_growth_path(period: 30)}']"
    assert_select "#growth_k", text: /#{I18n.t("#{SCOPE}.k_title")}/
    assert_select "#growth_k", text: /#{Regexp.escape(I18n.t("#{SCOPE}.target", target: "0,75", ambition: 2))}/
    assert_select "#growth_metrics li", 6
    assert_select "#growth_metrics", text: /#{I18n.t("#{SCOPE}.metrics.shares")}/
    assert_select "#growth_top_referrers li", text: /Aya Koné/
    assert_select "#growth_leaderboard li a[href='#{school_path(@school.public_id)}']", text: /Lycée Classique d'Abidjan/
    assert_select "#growth_pending a[href='#{school_path(@school.public_id)}']"
  end

  test "the period is 7, 30 or 90 days; anything else reads 30" do
    sign_in_as @member

    get teams_growth_path(period: 7)
    assert_select "nav#growth_periods a[aria-current=page][href='#{teams_growth_path(period: 7)}']"
    get teams_growth_path(period: 1000)
    assert_select "nav#growth_periods a[aria-current=page][href='#{teams_growth_path(period: 30)}']"
  end

  test "an empty platform reads dashes and empty states" do
    Orm::ReferralShare.delete_all
    Orm::Referral.delete_all
    Orm::TeacherSchool.delete_all
    sign_in_as @member

    get teams_growth_path

    assert_select "#growth_k", text: /—/
    assert_select "#growth_top_referrers", text: /#{I18n.t("#{SCOPE}.no_referrers")}/
    assert_select "#growth_leaderboard", text: /#{I18n.t("#{SCOPE}.no_schools")}/
    assert_select "#growth_pending", text: /#{I18n.t("#{SCOPE}.no_pending")}/
  end

  test "CP-18: a teacher and a student are refused in 403; no navigation entry leads here" do
    [ @aya, create_student(classroom: create_classroom(school: @school)) ].each do |user|
      sign_in_as user
      get teams_growth_path

      assert_response :forbidden
      sign_out
    end
    sign_in_as @member
    get team_home_path
    assert_select "#team_home_shortcuts a[href='#{teams_growth_path}']"
    assert_select "nav:not(#team_home_shortcuts) a[href='#{teams_growth_path}']", 0
    assert_not_includes NavigationHelper::DESTINATIONS.fetch(:team).map(&:second), :teams_growth_path
  end
end
