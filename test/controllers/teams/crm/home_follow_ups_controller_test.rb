require "test_helper"

# CA-20 (ADR-XXXX contexte crm, UDR-XXXX pipeline et relances): the « À relancer » card of the team home counts what is mine,
# gives the first three schools with their first reason, and leads to the page; admin and field only.
class Teams::Crm::HomeFollowUpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @field = create_team_member(team_role: "field")
    @admin = create_team_member(team_role: "admin")
  end

  def overdue_school(owner:, name: "École #{factory_sequence}")
    school = create_school(name:)
    Orm::CrmAccount.create!(school:, owner:, stage_changed_at: Time.current)
    Orm::CrmFollowUp.create!(school:, assignee: owner, due_on: Date.current - 1, reason: "Rappeler", created_by: owner)
    school
  end

  test "CA-20: three schools to follow up, two of them mine: the card counts 2 and leads to the page" do
    overdue_school(owner: @field, name: "Lycée Un")
    overdue_school(owner: @field, name: "Lycée Deux")
    overdue_school(owner: @admin, name: "Lycée Trois")
    sign_in_as @field

    get teams_home_follow_up_path, headers: { "Turbo-Frame" => "team_home_follow_ups" }

    assert_response :success
    assert_select "turbo-frame#team_home_follow_ups" do
      assert_select "a[href=?]", teams_follow_ups_path, count: 1
      assert_select "[data-count]", text: "2"
      assert_select "li", count: 2
    end
    assert_match(/Lycée Un/, response.body)
    assert_no_match(/Lycée Trois/, response.body)
    assert_match(/#{I18n.t("teams.crm.signals.reasons.overdue")}/, response.body)
  end

  test "the card lists three schools at most" do
    4.times { overdue_school(owner: @field) }
    sign_in_as @field

    get teams_home_follow_up_path, headers: { "Turbo-Frame" => "team_home_follow_ups" }

    assert_select "[data-count]", text: "4"
    assert_select "li", count: 3
  end

  test "nothing to follow up: the card says so" do
    sign_in_as @field

    get teams_home_follow_up_path

    assert_select "turbo-frame#team_home_follow_ups", text: /#{I18n.t("teams.crm.home_follow_ups.show.empty")}/
    assert_select "[data-count]", count: 0
  end

  test "content gets 403" do
    sign_in_as create_team_member(team_role: "content")
    get teams_home_follow_up_path
    assert_response :forbidden
  end
end
