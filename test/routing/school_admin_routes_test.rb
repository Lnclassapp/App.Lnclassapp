require "test_helper"

# UDR-0052 §3.0, UDR-0053 §3.2: every route of the direction, and the team and identity routes of the chantier
# espace-direction, are drawn by the Lot 0b with their exact helper names. The controllers arrive with the vertical lots:
# the routes are recognized without loading them. No numeric :id, no school identifier in the direction area (ADR-0066).
class SchoolAdminRoutesTest < ActionDispatch::IntegrationTest
  # [verb, path, controller#action, helper, helper arguments]
  DIRECTION = [
    [ "GET", "/school-admin", "homes#show", :school_admin_home_path, [] ],
    [ "GET", "/school-admin/classrooms", "classrooms#index", :school_admin_classrooms_path, [] ],
    [ "GET", "/school-admin/classrooms/c1", "classrooms#show", :school_admin_classroom_path, [ "c1" ] ],
    [ "POST", "/school-admin/level-classrooms", "level_classrooms#create", :school_admin_level_classrooms_path, [] ],
    [ "GET", "/school-admin/teachers", "teachers#index", :school_admin_teachers_path, [] ],
    [ "DELETE", "/school-admin/teachers/t1", "teachers#destroy", :school_admin_teacher_path, [ "t1" ] ],
    [ "GET", "/school-admin/teachers/departed", "departed_teachers#index", :school_admin_departed_teachers_path, [] ],
    [ "POST", "/school-admin/teachers/t1/reinstatement", "teacher_reinstatements#create", :school_admin_teacher_reinstatement_path,
      [ "t1" ] ],
    [ "GET", "/school-admin/students", "students#index", :school_admin_students_path, [] ],
    [ "GET", "/school-admin/students/placement/new", "student_placements#new", :new_school_admin_student_placement_path, [] ],
    [ "POST", "/school-admin/students/placement/lookup", "student_placements#lookup", :lookup_school_admin_student_placement_path, [] ],
    [ "GET", "/school-admin/students/s1/placement/edit", "student_placements#edit", :school_admin_edit_student_placement_path,
      [ "s1" ] ],
    [ "PATCH", "/school-admin/students/s1/placement", "student_placements#update", :school_admin_update_student_placement_path,
      [ "s1" ] ],
    [ "GET", "/school-admin/school", "schools#show", :school_admin_school_path, [] ],
    [ "GET", "/school-admin/school/code", "school_codes#show", :school_admin_school_code_path, [] ],
    [ "PATCH", "/school-admin/school/code", "school_codes#update", :school_admin_school_code_path, [] ],
    [ "GET", "/school-admin/school/staff", "staff_members#index", :school_admin_staff_members_path, [] ],
    [ "DELETE", "/school-admin/school/staff/u1", "staff_members#destroy", :school_admin_staff_member_path, [ "u1" ] ],
    [ "GET", "/school-admin/school/staff/invitations/new", "staff_invitations#new", :new_school_admin_staff_invitation_path, [] ],
    [ "POST", "/school-admin/school/staff/invitations", "staff_invitations#create", :school_admin_staff_invitations_path, [] ]
  ].freeze

  OTHERS = [
    [ "GET", "/teams/schools/e1/staff", "teams/school_staff_members#index", :school_staff_members_path, [ "e1" ] ],
    [ "DELETE", "/teams/schools/e1/staff/u1", "teams/school_staff_members#destroy", :school_staff_member_path, [ "e1", "u1" ] ],
    [ "GET", "/teams/schools/e1/staff/invitations/new", "teams/school_staff_invitations#new", :new_school_staff_invitation_path,
      [ "e1" ] ],
    [ "POST", "/teams/schools/e1/staff/invitations", "teams/school_staff_invitations#create", :school_staff_invitations_path, [ "e1" ] ],
    [ "POST", "/account/pending/school", "identity/school_rejoins#create", :school_rejoin_path, [] ],
    [ "GET", "/profile/student_number/edit", "identity/profile_student_numbers#edit", :edit_profile_student_number_path, [] ],
    [ "PATCH", "/profile/student_number", "identity/profile_student_numbers#update", :profile_student_number_path, [] ]
  ].freeze

  def helpers = Rails.application.routes.url_helpers

  # The first matching route, without loading its controller (see V1RoutesTest).
  def first_match(path, method:)
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action) }
    nil
  end

  def assert_route(method, path, target, helper, arguments)
    controller, action = target.split("#")
    assert_equal({ controller:, action: }, first_match(path, method:), "#{method} #{path}")
    assert_equal path, helpers.public_send(helper, *arguments), helper
  end

  test "the 20 routes of the direction area, with their exact helper names" do
    DIRECTION.each { |method, path, target, helper, arguments| assert_route(method, path, "school_admin/#{target}", helper, arguments) }
  end

  test "the direction area has exactly these 20 routes, none with a school identifier" do
    routes = Rails.application.routes.routes.select { it.defaults[:controller].to_s.start_with?("school_admin/") }

    assert_equal 20, routes.size
    assert_equal DIRECTION.map { |method, path, *| [ method, path ] }.sort,
                 routes.map { [ it.verb, it.path.spec.to_s.delete_suffix("(.:format)") ] }.map { |verb, spec| [ verb, sample(spec) ] }.sort
    assert routes.none? { it.path.spec.to_s.match?(/:school_|:id\b/) }
  end

  test "the team and identity routes of the chantier" do
    OTHERS.each { |method, path, target, helper, arguments| assert_route(method, path, target, helper, arguments) }
  end

  # ADR-0065, UDR-0053: only the student corrects their MENA number, from their profile.
  test "no team route touches a MENA number" do
    assert_nil first_match("/teams/accounts/u1/student-number", method: "PATCH")
    assert_nil first_match("/teams/accounts/u1/student-number/edit", method: "GET")
    assert Rails.application.routes.routes.none? { it.path.spec.to_s.match?(%r{\A/teams/.*student[-_]number}) }
  end

  # The departed teachers are drawn before the member routes of the teachers: « departed » is not a public id.
  test "departed is not read as a teacher" do
    assert_equal({ controller: "school_admin/departed_teachers", action: "index" }, first_match("/school-admin/teachers/departed", method: "GET"))
  end

  private

  SAMPLES = { ":public_id" => { "classrooms" => "c1", "teachers" => "t1" }, ":student_public_id" => "s1", ":user_public_id" => "u1" }.freeze

  # « /school-admin/classrooms/:public_id » → « /school-admin/classrooms/c1 », as the table writes it.
  def sample(spec)
    spec.gsub(/:\w+/) do |param|
      value = SAMPLES.fetch(param)
      value.is_a?(Hash) ? value.fetch(spec[%r{/school-admin/(\w+)}, 1]) : value
    end
  end
end
