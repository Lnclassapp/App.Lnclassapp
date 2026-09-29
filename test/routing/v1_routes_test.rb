require "test_helper"

# The V1 routes are the contract of the shell (Lot 0c, UDR-0006) and of every vertical lot
# (plan boucle-pedagogique §0a.4). No numeric :id is ever exposed (ADR-0029).
class V1RoutesTest < ActionDispatch::IntegrationTest
  FROZEN = %i[student_home_path student_classroom_path teacher_home_path teacher_classrooms_path team_home_path
              courses_path session_path schools_path profile_path team_dashboard_path].freeze
  # team_dashboard_path is drawn in V4 (pilotage-equipe, UDR-0049): no shell destination of these roles is left undrawn.
  NOT_IN_V1 = %i[].freeze

  def helpers = Rails.application.routes.url_helpers

  test "the frozen navigation names exist" do
    FROZEN.each { |name| assert helpers.respond_to?(name), name }
  end

  test "every destination of the student, teacher and team shells is drawn, except the later waves" do
    %i[student teacher team].each do |role|
      NavigationHelper::DESTINATIONS.fetch(role).map(&:second).each do |name|
        assert_equal NOT_IN_V1.exclude?(name), helpers.respond_to?(name), "#{role} → #{name}"
      end
    end
  end

  # The first matching route, without loading its controller: most are not merged yet. Routes are drawn lazily
  # (Rails 8) and the router alone does not draw them: `routes` does, whatever the order of the tests.
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action) }
    nil
  end

  # ADR-0055: the profile takes no identifier, it is always the account of the session (PR-02).
  test "the profile and its three forms are drawn under identity" do
    assert_equal "/profile", helpers.profile_path
    { "name" => "profile_names", "contact" => "profile_contacts", "pin" => "profile_pins" }.each do |part, controller|
      assert_equal "/profile/#{part}/edit", helpers.public_send(:"edit_profile_#{part}_path")
      assert_equal({ controller: "identity/#{controller}", action: "edit" }, first_match("/profile/#{part}/edit"))
      assert_equal({ controller: "identity/#{controller}", action: "update" }, first_match("/profile/#{part}", method: "PATCH"))
    end
    assert_equal({ controller: "identity/profiles", action: "show" }, first_match("/profile"))
    assert_nil first_match("/profile", method: "PATCH")
  end

  test "new is never captured by a slug or a public_id" do
    %w[courses levels series materials drenas].each do |resource|
      assert_equal({ controller: "teams/#{resource}", action: "new" }, first_match("/teams/#{resource}/new"))
    end
  end

  test "schools are created by JSON import only, never through a form" do
    assert_not helpers.respond_to?(:new_school_path)
    assert_nil first_match("/teams/schools", method: "POST")
    assert_equal({ controller: "teams/imports", action: "create" }, first_match("/teams/imports", method: "POST"))
    assert_equal({ controller: "teams/school_classrooms", action: "new" }, first_match("/teams/schools/abcdefghijkmno/classrooms/new"))
  end

  test "resources are addressed by public_id or slug" do
    assert_equal "/teams/schools/abcdefghijkmno", helpers.school_path("abcdefghijkmno")
    assert_equal "/courses/nombres-complexes", helpers.course_path("nombres-complexes")
    assert_equal "/c/abc23", helpers.join_classroom_path("abc23")
    assert_equal "/sessions/abcdefghijkmno/result", helpers.exercise_session_result_path("abcdefghijkmno")
    assert_equal "/teams/levels/tle/series/d", helpers.level_series_path("tle", "d")
    assert_equal "/drenas/abcdefghijkmno/schools", helpers.drena_schools_path("abcdefghijkmno")
  end

  # ADR-0057: a teacher signs up by the code of the school, typed or carried by /e/<code>; the team regenerates it.
  test "the school code has its short sign-up link and its regeneration under the school" do
    assert_equal "/e/k7m4qz", helpers.school_code_signup_path("k7m4qz")
    assert_equal({ controller: "identity/teacher_registrations", action: "with_code" }, first_match("/e/k7m4qz"))
    assert_nil first_match("/e/k7m4qz", method: "POST")
    assert_equal "/teams/schools/abcdefghijkmno/code", helpers.school_code_path("abcdefghijkmno")
    assert_equal({ controller: "teams/school_codes", action: "update" }, first_match("/teams/schools/abcdefghijkmno/code", method: "PATCH"))
  end

  test "no application route contains a numeric :id" do
    offenders = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
                     .reject { |path| path.start_with?("/rails/") }.grep(/:id\b/)

    assert_empty offenders
  end

  test "the jobs dashboard stays under the team area" do
    assert Rails.application.routes.routes.any? { |route| route.path.spec.to_s == "/teams/jobs" }
  end

  # ADR-0063: the growth routes; « Croissance » is no navigation destination (UDR-0006).
  test "the growth routes are drawn, none of them in the navigation" do
    { [ "/teachers/invite", "GET" ] => "identity/referrals#show", [ "/teachers/invite/shares", "POST" ] => "identity/referral_shares#create",
      [ "/teacher-signup/without-code", "GET" ] => "identity/pending_teacher_registrations#new",
      [ "/teacher-signup/without-code", "POST" ] => "identity/pending_teacher_registrations#create",
      [ "/teachers/join-requests/r1/vouch", "POST" ] => "school/join_request_vouches#create",
      [ "/teams/schools/s1/join-requests/r1", "PATCH" ] => "teams/join_requests#update",
      [ "/teams/growth", "GET" ] => "teams/growth#show" }.each do |(path, method), target|
      controller, action = target.split("#")
      assert_equal({ controller:, action: }, first_match(path, method:), "#{method} #{path}")
    end
    assert_not_includes NavigationHelper::DESTINATIONS.values.flatten, :teams_growth_path
  end
end
