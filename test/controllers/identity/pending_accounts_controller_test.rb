require "test_helper"

# ID-13, ADR-0030, ADR-0040: the exit screen of an account without a home never redirects.
class Identity::PendingAccountsControllerTest < ActionDispatch::IntegrationTest
  def t(key, **) = I18n.t("identity.pending_accounts.show.#{key}", **)

  test "a student without a classroom is invited to join one, without any loop" do
    sign_in_as create_student

    2.times do
      get pending_account_path

      assert_response :success
    end
    assert_select "h1.sr-only", t("page_title")
    assert_select "a[href='#{new_join_code_path}']", text: "Rejoindre une classe"
    assert_select "a[href='#{session_path}'][data-turbo-method=delete]", text: /Se déconnecter/
  end

  # GD-22 (ADR-0071, UDR-0056 §3.5) changes this case: a teacher without a school and without request types a code.
  test "a teacher without a school is offered to join one by its code" do
    sign_in_as create_user(role: "teacher")

    get pending_account_path

    assert_response :success
    assert_select "p", text: "Vous n'êtes rattaché à aucun établissement"
    assert_select "form#school-join-form"
    assert_select "a[href='#{new_join_code_path}']", 0
  end

  test "GD-22: a detached teacher, still signed in, is held on the waiting screen and reads the code field" do
    school = create_school
    teacher = create_teacher(school:)
    sign_in_as teacher
    Orm::TeacherSchool.where(teacher:).delete_all
    create_teacher_departure(teacher:, school:, detached_by: create_school_admin(school:))

    get teacher_home_path
    assert_redirected_to pending_account_path
    follow_redirect!

    assert_response :success
    assert_select "#pending_account" do
      assert_select "p", text: t("no_school.title")
      assert_select "p", text: t("no_school.description")
      assert_select "form#school-join-form[action='#{pending_school_join_path}'][method=post]" do
        assert_select "label[for=school_join_school_code]", text: /Code d'établissement/
        assert_select "input#school_join_school_code[name='school_join[school_code]'][required][autocomplete=off]" \
                      "[autocapitalize=characters][placeholder='K7M-4QZ'][aria-describedby=school_join_school_code_hint]" \
                      ".font-mono.tracking-wider.uppercase"
        assert_select "input#school_join_school_code[value]", 0
        assert_select "#school_join_school_code_hint", text: t("school_code_hint")
        assert_select "button[type=submit].w-full", text: t("join")
      end
      assert_select "a[href='#{session_path}'][data-turbo-method=delete]", text: /Se déconnecter/
    end
    assert_select "#join_request_rejected", 0
  end

  test "GD-22: a teacher whose request was approved, then detached, gets the form, without the request's message" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:, status: "approved")
    sign_in_as teacher

    get pending_account_path

    assert_select "form#school-join-form"
    assert_select "p", text: I18n.t("identity.pending_accounts.show.join_request.pending.title"), count: 0
  end

  test "GD-22: a refused request keeps its message above the form" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:, school: create_school(name: "Lycée Classique d'Abidjan"), status: "rejected")
    sign_in_as teacher

    get pending_account_path

    assert_select "#join_request_rejected", text: /#{I18n.t('identity.pending_accounts.show.join_request.rejected.title')}/
    assert_select "#join_request_rejected", text: /Lycée Classique d'Abidjan/
    assert_select "form#school-join-form"
  end

  test "GD-22: a teacher whose request is pending reads it, without the code form" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:)
    sign_in_as teacher

    get pending_account_path

    assert_select "p", text: I18n.t("identity.pending_accounts.show.join_request.pending.title")
    assert_select "form#school-join-form", 0
  end

  test "GD-28: the code of the invitation link is pre-filled, shown « K7M-4QZ »; a malformed one arrives as is" do
    sign_in_as create_teacher(school: nil)

    get pending_account_path(school_code: "k7m4qz")

    assert_select "input#school_join_school_code[value='K7M-4QZ']"
    assert_select "#school_join_school_code_error", 0

    get pending_account_path(school_code: "zz9")

    assert_select "input#school_join_school_code[value='zz9']"
    assert_select "#school_join_school_code_error", 0
  end

  test "a teacher attached to a school who opens the screen reads the generic teacher text, without the form" do
    sign_in_as create_teacher

    get pending_account_path

    assert_select "p", text: "Votre compte attend son école"
    assert_select "form#school-join-form", 0
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
