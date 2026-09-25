require "test_helper"

# ADR-0050: sign-in by phone number and PIN, one message on failure, rate limit, lockout, sign-out.
class Identity::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "the sign-in page shows the form" do
    get new_session_path

    assert_response :success
    assert_select "h2", text: "Connexion"
    assert_select "input[type=tel][name='session[contact]'][maxlength='15'][placeholder='07 00 00 00 00']"
    assert_select "input[type=password][name='session[pin]'][inputmode=numeric]"
    assert_select "a[href='#{new_identity_pin_reset_path}']", text: "PIN oublié ?"
  end

  test "a signed-in person who opens the sign-in page is sent home" do
    sign_in_as create_teacher

    get new_session_path

    assert_redirected_to teacher_home_path
  end

  test "a student with a classroom lands on the student home" do
    student = create_student(classroom: create_classroom)

    post session_path, params: { session: { contact: student.contact, pin: "2468" } }

    assert_redirected_to student_home_path
    assert_response :see_other
    assert_equal "Connexion réussie", flash[:notice]
    assert_equal 1, Orm::Session.where(user: student).count
  end

  test "the number is accepted with the 00225 and 225 prefixes" do
    teacher = create_teacher

    [ "00225 #{teacher.contact}", "+225#{teacher.contact}" ].each do |contact|
      post session_path, params: { session: { contact:, pin: "2468" } }

      assert_redirected_to teacher_home_path, contact
    end
  end

  test "each sign-in opens a new Rails session and a new token" do
    student = create_student
    sign_in_as student
    first_session_id = session.id
    first_token = cookies[:session_token]

    sign_in_as student

    assert_not_equal first_session_id, session.id
    assert_not_equal first_token, cookies[:session_token]
  end

  test "a wrong PIN re-renders the form in 422 with one message and no PIN" do
    student = create_student

    post session_path, params: { session: { contact: " 01 #{student.contact[2..]}", pin: "1357" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Numéro ou PIN incorrect."
    assert_select "input[name='session[contact]'][value=?]", " 01 #{student.contact[2..]}"
    assert_select "input[name='session[pin]']:not([value])"
  end

  test "a malformed PIN is shown under its field" do
    post session_path, params: { session: { contact: "0700000000", pin: "12" } }

    assert_response :unprocessable_entity
    assert_select "#session_pin_error", text: "Le PIN compte 4 chiffres."
  end

  test "a locked number receives 429 and the unlock time" do
    student = create_student
    5.times { create_login_attempt(contact: student.contact) }

    post session_path, params: { session: { contact: student.contact, pin: "2468" } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /Réessayez à/
  end

  test "a sixth attempt in a minute from the same address receives 429" do
    5.times { post session_path, params: { session: { contact: "0700000000", pin: "1357" } } }

    post session_path, params: { session: { contact: "0700000000", pin: "1357" } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /Trop de tentatives en une minute/
  end

  test "signing out ends the session and returns to the landing page" do
    sign_in_as create_student

    delete session_path

    assert_redirected_to root_path
    assert_equal "Vous êtes déconnecté", flash[:notice]
    assert_equal 0, Orm::Session.count
    assert_empty cookies[:session_token].to_s
  end

  test "a team member can sign out before the second factor" do
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    delete session_path

    assert_redirected_to root_path
    assert_equal 0, Orm::Session.count
  end
end
