require "test_helper"

# ID-15, F-07, UDR-0020: the team finds one account by its exact number; the result lives in the account_lookup
# frame, with the actions allowed on it.
class Teams::AccountLookupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @actor = create_team_member
    @student = create_student(classroom: create_classroom(name: "Tle D 2"), contact: "0511223344", first_name: "Awa", last_name: "Koné")
  end

  test "the page asks for a number, in a GET form aimed at the frame" do
    sign_in_as @actor

    get teams_account_lookup_path

    assert_response :success
    assert_select "h1", "Débloquer un compte"
    assert_select "form#account-lookup-form[method=get][action='#{teams_account_lookup_path}'][data-turbo-frame=account_lookup]" do
      assert_select "input[type=tel][name=contact][required]"
    end
    assert_select "turbo-frame#account_lookup", text: /Saisissez un numéro/
  end

  # UDR-0054 §3.2, §3.3, §3.9, amendment of UDR-0020: title, back to the home, arrival focus, search once the number is whole.
  test "the page is named, leads back to the home, focuses the number and searches by itself once it is complete" do
    sign_in_as @actor

    get teams_account_lookup_path

    assert_select "title", "Débloquer un compte · Équipe · Lnclass"
    assert_select "main nav[aria-label=Retour] a[href='#{team_home_path}']", "Accueil"
    assert_select "form#account-lookup-form[role=search][aria-label='Rechercher un compte'][data-controller=search][data-search-digits-value=true][data-search-min-length-value='0']" do
      assert_select "input#account_lookup_contact[data-autofocus-target=field][data-action='search#queue']"
      assert_select "input[autofocus]", 0
      assert_select "button[type=submit][data-search-target=button]", "Rechercher"
    end
    assert_select "turbo-frame#account_lookup.aria-busy\\:opacity-50"
  end

  test "a student is found by their number in any form: identity, classroom and the code button, no reset" do
    sign_in_as @actor

    get teams_account_lookup_path(contact: "+225 05 11 22 33 44")

    assert_select "turbo-frame#account_lookup #account-lookup-result" do
      assert_select "p", text: "Awa Koné"
      assert_select "dd", text: "Tle D 2"
      assert_select "form#pin-recovery-code-form[action='#{account_pin_recovery_codes_path(@student.public_id)}']"
      assert_select "form#second-factor-reset-form", 0
    end
    assert_select "input[name=contact][value='+225 05 11 22 33 44']"
  end

  test "from the frame, only the frame is rendered" do
    sign_in_as @actor

    get teams_account_lookup_path(contact: "0511223344"), headers: { "Turbo-Frame" => "account_lookup" }

    assert_response :success
    assert_select "h1", 0
    assert_select "form#account-lookup-form", 0
    assert_select "turbo-frame#account_lookup #account-lookup-result"
  end

  test "another team member can be reset; one's own account has no action" do
    member = create_team_member(contact: "0700000077")
    sign_in_as @actor

    get teams_account_lookup_path(contact: member.contact)
    assert_select "#account-second-factor", text: "Activé"
    assert_select "form#second-factor-reset-form[action='#{teams_member_second_factor_reset_path(member.public_id)}']"

    get teams_account_lookup_path(contact: @actor.contact)
    assert_select "#account-lookup-result", text: /Votre compte/
    assert_select "#account-lookup-result form", 0
  end

  test "an unknown or partial number finds nothing" do
    sign_in_as @actor

    [ "0511223345", "05112233" ].each do |contact|
      get teams_account_lookup_path(contact:)

      assert_select "#account-lookup-not-found", text: /Aucun compte pour ce numéro/
      assert_select "#account-lookup-result", 0
    end
  end

  test "a teacher and a student receive 403, a visitor is sent to the sign-in" do
    get teams_account_lookup_path
    assert_redirected_to new_session_path

    [ create_teacher, @student ].each do |user|
      sign_in_as user
      get teams_account_lookup_path(contact: "0511223344")
      assert_response :forbidden
      sign_out
    end
  end
end
