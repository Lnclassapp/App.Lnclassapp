require "test_helper"

# mvp-teacher-student, Lot 0: the two routes drawn for the lots that follow, names and paths frozen. The controllers come with
# their lots (Lot A: classroom/classroom_codes, Lot H: identity/profile_materials#show): the routes are recognized here
# without loading them. A route whose controller is missing answers with an error until its lot is merged.
class MvpTeacherStudentRoutesTest < ActionDispatch::IntegrationTest
  def helpers = Rails.application.routes.url_helpers

  # The first matching route, without loading its controller (Rails 8 draws the routes lazily: `routes` draws them).
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.slice(:controller, :action, :code) }
    nil
  end

  # ADR-XXXX code-de-classe-a-six-caracteres §4.4 (CA-B2): the code check, a page (Turbo Frame), never JSON.
  test "GET /classroom-codes/:code reaches classroom/classroom_codes#show" do
    assert_equal "/classroom-codes/k7m4q2", helpers.classroom_code_path("k7m4q2")
    assert_equal({ controller: "classroom/classroom_codes", action: "show", code: "k7m4q2" }, first_match("/classroom-codes/k7m4q2"))
    assert_nil first_match("/classroom-codes/k7m4q2", method: "POST")
    assert_nil first_match("/classroom-codes")
  end

  # UDR enseignant §3.4: the removal screen of the teacher's subjects; the edit and update routes stay.
  test "GET /profile/materials reaches identity/profile_materials#show, edit and update stay" do
    assert_equal "/profile/materials", helpers.profile_materials_path
    assert_equal "/profile/materials/edit", helpers.edit_profile_materials_path
    assert_equal({ controller: "identity/profile_materials", action: "show" }, first_match("/profile/materials"))
    assert_equal({ controller: "identity/profile_materials", action: "edit" }, first_match("/profile/materials/edit"))
    assert_equal({ controller: "identity/profile_materials", action: "update" }, first_match("/profile/materials", method: "PATCH"))
  end
end
