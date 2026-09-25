require "test_helper"

# ID-13, ADR-0030, ADR-0040: the exit screen of an account without a home never redirects.
class Identity::PendingAccountsControllerTest < ActionDispatch::IntegrationTest
  test "a student without a classroom is invited to join one, without any loop" do
    sign_in_as create_student

    2.times do
      get pending_account_path

      assert_response :success
    end
    assert_select "a[href='#{new_join_code_path}']", text: "Rejoindre une classe"
    assert_select "a[href='#{session_path}'][data-turbo-method=delete]", text: /Se déconnecter/
  end

  test "a teacher without a school waits for the team" do
    sign_in_as create_user(role: "teacher")

    get pending_account_path

    assert_response :success
    assert_select "p", text: "Votre compte attend son école"
    assert_select "a[href='#{new_join_code_path}']", 0
  end

  test "any other role gets the generic waiting screen" do
    sign_in_as create_user(role: "school_admin")

    get pending_account_path

    assert_response :success
    assert_select "p", text: "Votre compte est en attente"
  end
end
