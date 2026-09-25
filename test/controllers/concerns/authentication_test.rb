require "test_helper"

# ADR-0028, ADR-0031, ADR-0050: server session behind a signed cookie, second factor gate, role gate.
class AuthenticationTest < ActionDispatch::IntegrationTest
  class TeamProbeController < Teams::BaseController
    def show = head(:ok)
  end

  test "a visitor without a session is sent to the sign-in page" do
    get pending_account_path

    assert_redirected_to new_session_path
  end

  test "a forged cookie is no session" do
    cookies[:session_token] = "forged"

    get pending_account_path

    assert_redirected_to new_session_path
  end

  test "a student session ends after 30 days of inactivity" do
    sign_in_as create_student

    travel 30.days + 1.minute do
      get pending_account_path

      assert_redirected_to new_session_path
    end
    assert_equal 0, Orm::Session.count
  end

  test "an active session is touched and stays open" do
    student = create_student
    sign_in_as student

    travel 10.minutes do
      get pending_account_path

      assert_response :success
      assert_in_delta Time.current, Orm::Session.find_by!(user: student).last_seen_at, 1.second
    end
  end

  test "a team session ends 12 hours after it was opened, even when active" do
    sign_in_as create_team_member

    travel 12.hours + 1.second do
      get pending_account_path

      assert_redirected_to new_session_path
    end
  end

  test "a team account whose second factor is not verified reaches no page but the second factor" do
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    [ pending_account_path, "/teams/jobs", "/teams/jobs/queues" ].each do |path|
      get path

      assert_redirected_to "/identity/second-factor/new", path
    end
  end

  test "a team account without a second factor is sent to its enrollment" do
    member = create_team_member(second_factor: false)
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    get "/teams/jobs"

    assert_redirected_to "/identity/second-factor/enrollment/new"
  end

  test "a role outside the list receives 403" do
    sign_in_as create_teacher

    get "/teams/jobs"

    assert_response :forbidden
    assert_select "p", text: "Accès interdit."
  end

  test "a role in the list passes the role gate" do
    token = SecureRandom.base58(32)
    create_login_session(user: create_team_member, token:, second_factor_verified_at: Time.current)

    with_routing do |set|
      set.draw { get "probe", to: "authentication_test/team_probe#show" }
      cookies[:session_token] = signed_cookie(token)
      get "/probe"
    end

    assert_response :ok
  end

  test "the session cookie is signed, http only and lax" do
    sign_in_as create_student

    header = Array(response.headers["Set-Cookie"]).join("\n")

    assert_match(/session_token=[^;]+--/, header)
    assert_match(/httponly/i, header)
    assert_match(/samesite=lax/i, header)
  end

  private

  # with_routing opens a new integration session: the cookie is set by hand, signed like the application signs it.
  def signed_cookie(token)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_token] = token
    jar[:session_token]
  end
end
