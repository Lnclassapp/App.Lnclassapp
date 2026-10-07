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
    # The empty state is the whole page: its visible title is the page heading.
    assert_select "h1", 1
    assert_select "h1", t("student.title")
    assert_select "a[href='#{new_join_code_path}']", text: "Rejoindre une classe"
    assert_select "a[href='#{session_path}'][data-turbo-method=delete]", text: /Se déconnecter/
  end

  # GD-22 (ADR-0071), then IE-18 (ADR-0082): a teacher without a school and without request chooses one.
  test "a teacher without a school is offered to join one" do
    sign_in_as create_user(role: "teacher")

    get pending_account_path

    assert_response :success
    assert_select "h1", text: "Vous n'êtes rattaché à aucun établissement"
    assert_select "form#school-join-form"
    assert_select "a[href='#{new_join_code_path}']", 0
  end

  # IE-18 (ADR-0082 §4.3, UDR-0078 §3.9) replaces the code field of GD-22: the DRENA, then the school, as at sign-up.
  test "IE-18: a detached teacher, still signed in, is held on the waiting screen and chooses a DRENA, no code field" do
    abidjan = create_drena(name: "Abidjan 1")
    school = create_school(drena: abidjan)
    teacher = create_teacher(school:)
    sign_in_as teacher
    Orm::TeacherSchool.where(teacher:).delete_all
    create_teacher_departure(teacher:, school:, detached_by: create_school_admin(school:))

    get teacher_home_path
    assert_redirected_to pending_account_path
    follow_redirect!

    assert_response :success
    assert_select "#pending_account" do
      assert_select "h1", text: t("no_school.title")
      assert_select "p", text: t("no_school.description")
      assert_select "form#school-join-drena[action='#{pending_account_path}'][method=get]"
      assert_select "form#school-join-form[action='#{pending_school_join_path}'][method=post]" \
                    "[data-controller~='school--drena-schools']" do
        assert_select "label[for=school_join_drena_public_id]", text: /DRENA/
        assert_select "select#school_join_drena_public_id[name='school_join[drena_public_id]'][form=school-join-drena]" \
                      "[data-action='change->school--drena-schools#load']" do
          assert_select "option[value='']", text: t("drena_prompt")
          assert_select "option[value=?]", abidjan.public_id, text: "Abidjan 1"
        end
        assert_select "noscript", text: /#{t('show_schools')}/
        assert_select "turbo-frame#schools" do
          assert_select "select#school_join_school_public_id[name='school_join[school_public_id]'][disabled][required]"
          assert_select "#school_join_school_public_id_hint", text: "Choisissez d'abord votre DRENA."
        end
        assert_select "button[type=submit].w-full", text: t("join")
      end
      assert_select "a[href='#{session_path}'][data-turbo-method=delete]", text: /Se déconnecter/
    end
    assert_select "input[name*=school_code], #school_join_school_code", 0
    assert_select "#pending_account", text: /Code d'établissement/, count: 0
    assert_select "#join_request_rejected", 0
  end

  test "IE-18: without JavaScript, the chosen DRENA comes back by GET and lists its active schools" do
    abidjan = create_drena(name: "Abidjan 1")
    classique = create_school(drena: abidjan, name: "Lycée Classique d'Abidjan")
    create_school(drena: abidjan, name: "Lycée fermé", status: "inactive")
    create_school(name: "Lycée de Bouaké")
    sign_in_as create_teacher(school: nil)

    get pending_account_path(school_join: { drena_public_id: abidjan.public_id })

    assert_response :success
    assert_select "select#school_join_drena_public_id option[selected][value=?]", abidjan.public_id
    assert_select "turbo-frame#schools" do
      assert_select "input[type=hidden][name='school_join[drena_public_id]'][value=?]", abidjan.public_id
      assert_select "select#school_join_school_public_id:not([disabled]) option[value]:not([value=''])", 1
      assert_select "select#school_join_school_public_id option[value=?]", classique.public_id, text: "Lycée Classique d'Abidjan"
    end
    assert_select "#school_join_school_public_id_error", 0
  end

  # ADR-0082 §4.5: /drenas/:drena_public_id/schools is again the source of the list, in the scope of the join form.
  test "IE-18: the frame of the schools is fed by /drenas/:id/schools, in the school_join scope" do
    sign_in_as create_teacher(school: nil)

    get pending_account_path

    url = drena_schools_path("__drena__", scope: "school_join")
    assert_equal "/drenas/__drena__/schools?scope=school_join", url
    assert_select "form#school-join-form[data-school--drena-schools-url-value=?]", url
  end

  test "IE-18: an unknown DRENA lists nothing; a school code in the address pre-fills nothing" do
    sign_in_as create_teacher(school: nil)

    get pending_account_path(school_join: { drena_public_id: "inconnue" }, school_code: "k7m4qz")

    assert_response :success
    assert_select "select#school_join_school_public_id[disabled]"
    assert_select "input[name*=school_code]", 0
    assert_select "#pending_account", text: /K7M-4QZ/i, count: 0
  end

  test "GD-22: a teacher whose request was approved, then detached, gets the form, without the request's message" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:, status: "approved")
    sign_in_as teacher

    get pending_account_path

    assert_select "form#school-join-form"
    assert_select "h1", text: I18n.t("identity.pending_accounts.show.join_request.pending.title"), count: 0
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

  test "GD-22: a teacher whose request is pending reads it, without the join form" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:)
    sign_in_as teacher

    get pending_account_path

    assert_select "h1", text: I18n.t("identity.pending_accounts.show.join_request.pending.title")
    assert_select "form#school-join-form", 0
  end

  test "a teacher attached to a school who opens the screen reads the generic teacher text, without the form" do
    sign_in_as create_teacher

    get pending_account_path

    assert_select "h1", text: "Votre compte attend son école"
    assert_select "form#school-join-form", 0
  end

  test "CP-11: a teacher who signed up without code reads that the request of their school is being validated" do
    teacher = create_teacher(school: nil)
    create_join_request(school: create_school(name: "Lycée Classique d'Abidjan"), teacher:)
    sign_in_as teacher

    get pending_account_path

    assert_response :success
    assert_select "h1", text: I18n.t("identity.pending_accounts.show.join_request.pending.title")
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
    assert_select "h1", text: "Votre compte est en attente"
  end
end
