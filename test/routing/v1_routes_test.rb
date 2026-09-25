require "test_helper"

# The V1 routes are the contract of the shell (Lot 0c, UDR-0006) and of every vertical lot
# (plan boucle-pedagogique §0.10). No numeric :id is ever exposed (ADR-0029).
class V1RoutesTest < ActionDispatch::IntegrationTest
  FROZEN = %i[student_home_path student_classroom_path teacher_home_path teacher_classrooms_path team_home_path
              courses_path session_path schools_path].freeze
  NOT_IN_V1 = %i[team_dashboard_path profile_path].freeze

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
    assert_not helpers.respond_to?(:profile_path)
  end

  # The first matching route, without loading its controller: most are not merged yet.
  def first_match(path)
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action) }
  end

  test "new is never captured by a slug or a public_id" do
    %w[courses schools levels series materials drenas].each do |resource|
      assert_equal({ controller: "teams/#{resource}", action: "new" }, first_match("/teams/#{resource}/new"))
    end
  end

  test "resources are addressed by public_id or slug" do
    assert_equal "/teams/schools/abcdefghijkmno", helpers.school_path("abcdefghijkmno")
    assert_equal "/courses/nombres-complexes", helpers.course_path("nombres-complexes")
    assert_equal "/c/abc23", helpers.join_classroom_path("abc23")
    assert_equal "/sessions/abcdefghijkmno/result", helpers.exercise_session_result_path("abcdefghijkmno")
    assert_equal "/teams/levels/tle/series/d", helpers.level_series_path("tle", "d")
  end

  test "no application route contains a numeric :id" do
    offenders = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
                     .reject { |path| path.start_with?("/rails/") }.grep(/:id\b/)

    assert_empty offenders
  end

  test "the jobs dashboard stays under the team area" do
    assert Rails.application.routes.routes.any? { |route| route.path.spec.to_s == "/teams/jobs" }
  end
end
