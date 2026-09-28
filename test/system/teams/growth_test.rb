require "application_system_test_case"

# CP-16 to CP-18 (ADR-0063, UDR-0050): from the team home, « Croissance » opens the growth page: k and its decomposition,
# the metrics, the referrers, the ranking of schools and the pending requests. On a desktop and on a 390 px phone.
class Teams::GrowthTest < ApplicationSystemTestCase
  SCOPE = "teams.growth.show".freeze

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    aya = create_teacher(school:, first_name: "Aya", last_name: "Koné", created_at: 10.days.ago)
    2.times { create_referral(referrer: aya, referee: create_teacher(school:, created_at: 5.days.ago), created_at: 5.days.ago) }
    6.times { create_referral_share(user: aya, created_at: 8.days.ago) }
    create_join_request(school:)
    @member = create_team_member
  end

  test "CP-18: the team reaches « Croissance » from its home and reads the indicators of the period" do
    sign_in_as @member
    click_on I18n.t("teams.homes.shortcuts.growth")

    assert_current_path teams_growth_path
    assert_selector "h1", text: I18n.t("#{SCOPE}.title")
    within("#growth_top_referrers") { assert_text "Aya Koné" }
    within("#growth_leaderboard") { assert_text "Lycée Classique d'Abidjan" }
    growth_shot("1280-page-croissance")

    click_on I18n.t("#{SCOPE}.period", count: 7)
    assert_selector "nav#growth_periods a[aria-current=page]", text: I18n.t("#{SCOPE}.period", count: 7)
  end

  test "on a 390 px phone, the page fits the width" do
    with_mobile_viewport do
      sign_in_as @member
      visit teams_growth_path

      assert_selector "#growth_k"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
      growth_shot("390-page-croissance", desktop: false)
    end
  end
end
