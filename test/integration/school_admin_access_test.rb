require "test_helper"

# ED-01, ED-02, ED-03, ADR-0066 §4.2: every route of the direction area whose controller is merged — parametrized on
# Rails.application.routes, so that each vertical lot is covered as soon as its controller arrives (plan, exit gate: the
# 20 routes at the end of wave 3). The ids of the paths are fake: every guard answers before any record is read.
class SchoolAdminAccessTest < ActionDispatch::IntegrationTest
  SAMPLE = { public_id: "x1", student_public_id: "x1", user_public_id: "x1" }.freeze

  def self.direction_routes
    Rails.application.routes.routes.select do |route|
      controller = route.defaults[:controller].to_s
      controller.start_with?("school_admin/") && "#{controller.camelize}Controller".safe_constantize
    end
  end

  def direction_requests
    routes = self.class.direction_routes
    assert_operator routes.size, :>=, 2, "homes#show et schools#show sont livrés au Lot 0b"
    routes.map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)").gsub(/:(\w+)/) { SAMPLE.fetch(::Regexp.last_match(1).to_sym) }
      [ route.verb.downcase.to_sym, path ]
    end
  end

  def each_request
    direction_requests.each do |verb, path|
      public_send(verb, path)
      yield "#{verb.upcase} #{path}"
    end
  end

  test "ED-01: a principal signed in by PIN only is sent to the second factor on every route" do
    principal = create_school_admin
    post session_path, params: { session: { contact: principal.contact, pin: "2468" } }

    each_request do |request|
      assert_redirected_to new_identity_second_factor_path, request
      assert_no_match(/school_admin|Tableau de bord/, response.body, request)
    end
  end

  test "ED-01: without a second factor yet, the direction is sent to its enrollment" do
    member = create_school_admin(second_factor: false)
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    each_request { assert_redirected_to new_identity_second_factor_enrollment_path, it }
  end

  test "ED-02: a student, a teacher and a team member, verified, receive 403 on every route" do
    [ create_student(classroom: create_classroom), create_teacher, create_team_member ].each do |account|
      sign_in_as account

      each_request { assert_response :forbidden, "#{account.role} #{it}" }
      sign_out
    end
  end

  test "a visitor is sent to the sign-in on every route" do
    each_request { assert_redirected_to new_session_path, it }
  end

  test "ED-03: a member whose attachment ended, or whose school is inactive, is held on the waiting screen, catalogue included" do
    left = create_school_admin
    Orm::SchoolStaff.where(user_id: left.id).update_all(left_at: Time.current)
    school = create_school
    inactive = create_school_admin(school:, position: "censor")
    school.update!(status: "inactive")

    [ left, inactive ].each do |member|
      sign_in_as member

      each_request { assert_redirected_to pending_account_path, it }
      [ courses_path, school_admin_home_path ].each do |path|
        get path
        assert_redirected_to pending_account_path, path
      end
      follow_redirect!
      assert_select "#pending_account", text: /Aucun établissement/
      get profile_path
      assert_response :success
      sign_out
    end
  end

  test "an attached principal opens the routes delivered by the Lot 0b" do
    sign_in_as create_school_admin

    [ school_admin_home_path, school_admin_school_path ].each do |path|
      get path
      assert_response :success, path
    end
  end
end
