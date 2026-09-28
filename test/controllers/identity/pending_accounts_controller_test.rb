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

  test "CP-11: a teacher who signed up without code reads that the request of their school is being validated" do
    teacher = create_teacher(school: nil)
    create_join_request(school: create_school(name: "Lycée Classique d'Abidjan"), teacher:)
    sign_in_as teacher

    get pending_account_path

    assert_response :success
    assert_select "p", text: I18n.t("identity.pending_accounts.show.join_request.pending.title")
    assert_select "#pending_account", text: /Lycée Classique d'Abidjan/
  end

  test "CP-12: a teacher whose request was refused reads it" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:, status: "rejected")
    sign_in_as teacher

    get pending_account_path

    assert_select "p", text: I18n.t("identity.pending_accounts.show.join_request.rejected.title")
  end

  test "CP-11: a teacher without school is held on the waiting screen: catalog, profile, invitation lead back to it" do
    sign_in_as create_teacher(school: nil)

    [ courses_path, profile_path, teacher_invite_path, teacher_classrooms_path ].each do |path|
      get path

      assert_redirected_to pending_account_path, path
    end
    post teacher_referral_shares_path, params: { channel: "sms" }
    assert_response :forbidden, "m6 : le PRD répond 403 à l'enregistrement d'un partage"
    assert_equal 0, Orm::ReferralShare.count
  end

  test "any other role gets the generic waiting screen" do
    sign_in_as create_user(role: "school_admin")

    get pending_account_path

    assert_response :success
    assert_select "p", text: "Votre compte est en attente"
  end
end
