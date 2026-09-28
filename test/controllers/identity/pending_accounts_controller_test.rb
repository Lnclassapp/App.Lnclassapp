require "test_helper"

# ID-13, ADR-0030, ADR-0040: the exit screen of an account without a home never redirects.
# ED-03, ED-35, UDR-0052 §3.9: its four cases, in order — direction without school, teacher with a request, teacher
# without school (removed, or approved then removed), the others.
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

  def assert_rejoin_form
    assert_select "form#school-rejoin-form[action='#{school_rejoin_path}'][method=post]" do
      assert_select "label[for=school_rejoin_school_code]", text: /Code d'établissement/
      assert_select "input#school_rejoin_school_code[name='school_rejoin[school_code]'][required][autocomplete=off][placeholder='K7M-4QZ']"
      assert_select "button[type=submit]", text: "Rejoindre l'établissement"
    end
  end

  test "ED-35: a teacher without a school nor any request reads that they are attached to no school, with the code field" do
    sign_in_as create_teacher(school: nil)

    get pending_account_path

    assert_response :success
    assert_select "#pending_account p", text: "Vous n'êtes rattaché à aucun établissement"
    assert_select "#pending_account", text: /Retiré par erreur \? Demandez à votre ancienne direction de vous réintégrer\./
    assert_rejoin_form
    assert_select "a[href='#{session_path}'][data-turbo-method=delete]", text: /Se déconnecter/
    assert_select "a[href='#{new_join_code_path}']", 0
  end

  test "ED-35: a teacher whose request was approved, then who was removed, gets the code field, not « en cours »" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:, status: "approved")
    sign_in_as teacher

    get pending_account_path

    assert_select "#pending_account p", text: "Vous n'êtes rattaché à aucun établissement"
    assert_select "p", text: I18n.t("identity.pending_accounts.show.join_request.pending.title"), count: 0
    assert_rejoin_form
  end

  # UDR-0052 §3.9: the school rejoin controller (Lot C) re-renders this view with its DTO in error.
  test "the code field keeps the input and shows the error of the DTO given by the rejoin" do
    sign_in_as create_teacher(school: nil)
    rejoin = Struct.new(:school_code, :errors).new("abc", ActiveModel::Errors.new(Object.new))
    rejoin.errors.add(:school_code, "Code d'établissement invalide.")

    view = Identity::PendingAccountsController.render(:show, assigns: { case: :teacher_without_school, rejoin: },
                                                              layout: false)

    assert_includes view, 'value="abc"'
    assert_includes view, 'aria-invalid="true"'
    assert_includes view, "Code d&#39;établissement invalide."
  end

  test "CP-11: a teacher who signed up without code reads that the request of their school is being validated" do
    teacher = create_teacher(school: nil)
    create_join_request(school: create_school(name: "Lycée Classique d'Abidjan"), teacher:)
    sign_in_as teacher

    get pending_account_path

    assert_response :success
    assert_select "p", text: I18n.t("identity.pending_accounts.show.join_request.pending.title")
    assert_select "#pending_account", text: /Lycée Classique d'Abidjan/
    assert_select "#school-rejoin-form", 0
  end

  test "CP-12: a teacher whose request was refused reads it" do
    teacher = create_teacher(school: nil)
    create_join_request(teacher:, status: "rejected")
    sign_in_as teacher

    get pending_account_path

    assert_select "p", text: I18n.t("identity.pending_accounts.show.join_request.rejected.title")
    assert_rejoin_form
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

  test "ED-03: a member of the direction without school reads « Aucun établissement », with their profile and the sign-out" do
    sign_in_as create_user(role: "school_admin")

    get pending_account_path

    assert_response :success
    assert_select "#pending_account p", text: "Aucun établissement"
    assert_select "#pending_account", text: /Votre compte de direction n'est rattaché à aucun établissement actif\. Contactez l'équipe Lnclass\./
    assert_select "#pending_account a[href='#{profile_path}']", text: /Mon profil/
    assert_select "#pending_account a[href='#{session_path}'][data-turbo-method=delete]", text: /Se déconnecter/
    assert_select "#school-rejoin-form", 0
  end

  test "any other account gets the generic waiting screen: a team member, an attached teacher or member of the direction" do
    [ create_team_member, create_teacher, create_school_admin ].each do |account|
      sign_in_as account

      get pending_account_path

      assert_response :success
      assert_select "p", text: "Votre compte est en attente"
      assert_select "#school-rejoin-form", 0
      sign_out
    end
  end
end
