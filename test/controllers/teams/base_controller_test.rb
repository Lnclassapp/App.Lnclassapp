require "test_helper"

# ADR-0028, ADR-0031, ADR-0052: the team area, Mission Control Jobs included, is reserved to the team,
# second factor verified.
class Teams::BaseControllerTest < ActionDispatch::IntegrationTest
  test "the jobs dashboard sends a visitor to the sign-in page" do
    get "/teams/jobs"

    assert_redirected_to "/login"
  end

  test "a teacher receives 403" do
    sign_in_as create_teacher

    get "/teams/jobs"

    assert_response :forbidden
    # UDR-0054 §3.1: the error page, rendered under the engine, still names itself (config/initializers/mission_control_jobs.rb).
    assert_select "title", "Accès interdit · Enseignant · Lnclass"
  end

  test "without an argument, page_title stays the reader of the engine, for its own pages" do
    view = ActionView::Base.empty.extend(MissionControl::Jobs::NavigationHelper)
    view.instance_variable_set(:@page_title, "Queues")

    assert_equal "Queues", view.page_title
  end

  test "a team member whose second factor is not verified is sent to the second factor" do
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    get "/teams/jobs"

    assert_redirected_to "/identity/second-factor/new"
  end

  test "the jobs dashboard is refused to a team member without a second factor" do
    member = create_team_member(second_factor: false)
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    get "/teams/jobs"

    assert_redirected_to "/identity/second-factor/enrollment/new"
  end

  test "mission control inherits the team area guard" do
    assert_equal "Teams::BaseController", MissionControl::Jobs.base_controller_class
    assert_operator Teams::BaseController, :<, AuthenticatedController
    assert_not MissionControl::Jobs.http_basic_auth_enabled
  end
end
