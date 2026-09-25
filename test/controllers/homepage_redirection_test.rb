require "test_helper"

# TR-02: the landing page is public; a signed-in person is sent to their home.
class HomepageRedirectionTest < ActionDispatch::IntegrationTest
  test "a visitor sees the landing page" do
    get root_path

    assert_response :success
  end

  test "a signed-in student without a classroom is sent to the pending account screen" do
    sign_in_as create_student

    get root_path

    assert_redirected_to pending_account_path
  end

  test "a signed-in teacher is sent to the teacher home" do
    sign_in_as create_teacher

    get root_path

    assert_redirected_to teacher_home_path
  end

  test "a team member not yet verified is sent to the second factor" do
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    get root_path

    assert_redirected_to new_identity_second_factor_path
  end
end
