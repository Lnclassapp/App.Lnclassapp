require "test_helper"

# DS-11 (chantier espace-direction-simple, Lot 0): the direction reads, it never writes (ADR-0065). Its pages are
# drawn under /school-admin, GET only; the team invites it from the page of a school.
class SchoolAdminRoutesTest < ActionDispatch::IntegrationTest
  def helpers = Rails.application.routes.url_helpers

  # The first matching route, without loading its controller (Lots B and C bring them).
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action, :public_id) }
    nil
  end

  test "the two pages of the direction and the page of a classroom are drawn" do
    assert_equal "/school-admin/classrooms", helpers.school_admin_classrooms_path
    assert_equal "/school-admin/classrooms/abcdefghijkmno", helpers.school_admin_classroom_path("abcdefghijkmno")
    assert_equal "/school-admin/teachers", helpers.school_admin_teachers_path

    assert_equal({ controller: "school_admin/classrooms", action: "index" }, first_match("/school-admin/classrooms"))
    assert_equal({ controller: "school_admin/classrooms", action: "show", public_id: "abcdefghijkmno" },
                 first_match("/school-admin/classrooms/abcdefghijkmno"))
    assert_equal({ controller: "school_admin/teachers", action: "index" }, first_match("/school-admin/teachers"))
  end

  test "no route under /school-admin accepts anything but GET" do
    routes = Rails.application.routes.routes.select { it.path.spec.to_s.start_with?("/school-admin") }

    assert_not_empty routes
    routes.each { |route| assert_equal "GET", route.verb, route.path.spec.to_s }
    %w[POST PATCH PUT DELETE].each do |method|
      %w[/school-admin/classrooms /school-admin/classrooms/abcdefghijkmno /school-admin/teachers].each do |path|
        assert_nil first_match(path, method:), "#{method} #{path}"
      end
    end
  end

  test "the team invites the direction from the page of a school" do
    assert_equal "/teams/schools/abcdefghijkmno/staff-invitations/new", helpers.new_school_staff_invitation_path("abcdefghijkmno")
    assert_equal "/teams/schools/abcdefghijkmno/staff-invitations", helpers.school_staff_invitations_path("abcdefghijkmno")

    assert_equal({ controller: "teams/staff_invitations", action: "new" },
                 first_match("/teams/schools/abcdefghijkmno/staff-invitations/new"))
    assert_equal({ controller: "teams/staff_invitations", action: "create" },
                 first_match("/teams/schools/abcdefghijkmno/staff-invitations", method: "POST"))
  end
end
