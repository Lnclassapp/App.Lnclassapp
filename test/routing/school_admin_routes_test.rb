require "test_helper"

# DS-11 (chantier espace-direction-simple, Lot 0): the direction reads, it never writes (ADR-0065). Its pages are
# drawn under /school-admin, GET only; the team invites it from the page of a school.
class SchoolAdminRoutesTest < ActionDispatch::IntegrationTest
  def helpers = Rails.application.routes.url_helpers

  # The first matching route, without loading its controller (Lots B and C bring them).
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action, :public_id, :slug) }
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

  # AD-09, AD-17 (UDR-0074 §3.8, §3.11): the page of a level, by its frozen slug, and the deferred activity of the home.
  test "the page of a level and the activity of the home are drawn, GET only" do
    assert_equal "/school-admin/levels/3eme", helpers.school_admin_level_path("3eme")
    assert_equal "/school-admin/activity", helpers.school_admin_activity_path

    assert_equal({ controller: "school_admin/levels", action: "show", slug: "3eme" }, first_match("/school-admin/levels/3eme"))
    assert_equal({ controller: "school_admin/activities", action: "show" }, first_match("/school-admin/activity"))
    %w[POST PATCH PUT DELETE].each do |method|
      %w[/school-admin/levels/3eme /school-admin/activity].each { assert_nil first_match(it, method:), "#{method} #{it}" }
    end
  end

  # ADR-0071, UDR-0056 §3.0 (gestion-etablissement-direction, Lot 0) amends DS-11: the direction's gestures are its only
  # writes, a closed list; its reading pages still accept GET alone. ADR-0083 §4.5: « Changer le lien » is gone.
  WRITES = [ [ "DELETE", "/school-admin/teachers/:public_id(.:format)" ],
             [ "POST", "/school-admin/teachers/:public_id/reinstatement(.:format)" ],
             [ "POST", "/school-admin/school/level-classrooms(.:format)" ],
             [ "DELETE", "/school-admin/school/level-classrooms/:public_id(.:format)" ],
             # ADR-0088 : archiver et restaurer une classe, archiver un niveau.
             [ "PATCH", "/school-admin/school/classroom-archivals/:public_id/archive(.:format)" ],
             [ "PATCH", "/school-admin/school/classroom-archivals/:public_id/restore(.:format)" ],
             [ "POST", "/school-admin/school/level-archivals(.:format)" ],
             # ADR-0077 : retirer une autre direction.
             [ "DELETE", "/school-admin/school/staff/:public_id(.:format)" ] ].freeze

  test "under /school-admin, only the direction's gestures accept anything but GET" do
    routes = Rails.application.routes.routes.select { it.path.spec.to_s.start_with?("/school-admin") }

    assert_not_empty routes
    assert_equal WRITES.sort, routes.reject { it.verb == "GET" }.map { [ it.verb, it.path.spec.to_s ] }.sort
    %w[POST PATCH PUT DELETE].each do |method|
      %w[/school-admin/classrooms /school-admin/classrooms/abcdefghijkmno /school-admin/teachers /school-admin/school].each do |path|
        assert_nil first_match(path, method:), "#{method} #{path}"
      end
    end
  end

  # Lot 3 of ecrans-direction-lents (UDR-0056, amendment of 2026-10-04): the confirmation « Retirer » is read on demand.
  test "the confirmation of a teacher's withdrawal is a page of its own, GET only" do
    assert_equal "/school-admin/teachers/abcdefghijkmno/removal", helpers.school_admin_teacher_removal_path("abcdefghijkmno")
    assert_equal({ controller: "school_admin/teachers", action: "removal", public_id: "abcdefghijkmno" },
                 first_match("/school-admin/teachers/abcdefghijkmno/removal"))
    %w[POST PATCH PUT DELETE].each { assert_nil first_match("/school-admin/teachers/abcdefghijkmno/removal", method: it), it }
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
