require "test_helper"

# ADR-0031, ADR-0050: TOTP verification once per session, replay refused, backup codes single use.
class Identity::SecondFactorsControllerTest < ActionDispatch::IntegrationTest
  setup { @member = create_team_member }

  # FU-34, FU-39 (UDR-0054 §3.6): six digits leave by themselves; the hint says so and is tied to the field.
  test "an unverified team member sees the code form, sent at the sixth digit" do
    sign_in_pin(@member)

    get new_identity_second_factor_path

    assert_response :success
    assert_select "title", "Vérification · Lnclass"
    assert_select "form#second-factor-form[data-controller=autosubmit][data-autosubmit-pattern-value=?]", '^\d{6}$' do
      assert_select "input[name='second_factor[code]'][autocomplete=one-time-code][inputmode=numeric][maxlength='6']" \
                    "[pattern=?][data-autosubmit-target=input][data-autofocus-target=field][aria-describedby=second_factor_code_hint]", '\d{6}'
      assert_select "#second_factor_code_hint", text: "Le code est envoyé dès le 6ᵉ chiffre."
      assert_select "[data-autosubmit-target=status][aria-live=polite].sr-only"
      assert_select "input[name=backup]", 0
    end
    assert_select "form#second-factor-form[data-autosubmit-message-value=?]", "Envoi du code…"
    assert_select "a[href=?]:not([data-turbo-action])", new_identity_second_factor_path(backup: 1),
                  text: "J'utilise un code de secours"
    assert_select "a[href=?][data-turbo-method=delete]", session_path, text: "Se déconnecter"
  end

  # FU-37: the backup code has its own field, never sent by itself; the link works without JavaScript.
  test "the backup variant has its own field, without automatic sending" do
    sign_in_pin(@member)

    get new_identity_second_factor_path(backup: 1)

    assert_response :success
    assert_select "form#second-factor-form[data-controller]", 0
    assert_select "label[for=second_factor_code]", text: /Code de secours/
    assert_select "input[name='second_factor[code]'][inputmode=text][autocomplete=off][autocapitalize=none]" \
                  "[maxlength='12'][data-autofocus-target=field]:not([pattern]):not([data-autosubmit-target])"
    assert_select "input[type=hidden][name=backup][value='1']"
    assert_select "a[href=?]:not([data-turbo-action])", new_identity_second_factor_path,
                  text: "Utiliser le code de l'application"
    assert_select "a", text: "J'utilise un code de secours", count: 0
  end

  test "a wrong backup code re-renders the backup variant in 422" do
    sign_in_pin(@member)

    post identity_second_factor_path, params: { backup: "1", second_factor: { code: "Zz9kP9wQ2m" } }

    assert_response :unprocessable_entity
    assert_select "#second_factor_code_error", text: "Code incorrect."
    assert_select "input[name='second_factor[code]'][value=''][aria-invalid=true][inputmode=text]"
    assert_select "input[type=hidden][name=backup][value='1']"
    assert_select "form#second-factor-form[data-controller]", 0
  end

  # FU-35: one wrong code is one journaled attempt, and the field comes back empty.
  test "a wrong code is one attempt and comes back empty, in the code variant" do
    sign_in_pin(@member)

    assert_difference -> { Orm::LoginAttempt.where(contact: @member.contact, kind: "second_factor").count }, 1 do
      post identity_second_factor_path, params: { second_factor: { code: "000000" } }
    end

    assert_response :unprocessable_entity
    assert_select "input[name='second_factor[code]'][value=''][aria-invalid=true][inputmode=numeric]"
    assert_select "form#second-factor-form[data-controller=autosubmit]"
    assert_select "input[name=backup]", 0
  end

  test "the current code verifies the session and opens the team home" do
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: current_code } }

    assert_redirected_to team_home_path
    assert_response :see_other
    assert_not_nil Orm::Session.find_by!(user: @member).second_factor_verified_at
  end

  test "a code already used is refused" do
    freeze_time do
      sign_in_as @member
      delete session_path
      sign_in_pin(@member)

      post identity_second_factor_path, params: { second_factor: { code: current_code } }

      assert_response :unprocessable_entity
      assert_select "#second_factor_code_error", text: "Code incorrect."
    end
  end

  test "a backup code is accepted once" do
    create_backup_code(user: @member, code: "Hx3kP9wQ2m")
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: "Hx3k P9wQ 2m" } }

    assert_redirected_to team_home_path

    delete session_path
    sign_in_pin(@member)
    post identity_second_factor_path, params: { second_factor: { code: "Hx3kP9wQ2m" } }

    assert_response :unprocessable_entity
  end

  test "a blank code is shown under its field" do
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: "" } }

    assert_response :unprocessable_entity
    assert_select "#second_factor_code_error"
  end

  test "too many failures lock the second factor" do
    5.times { create_login_attempt(contact: @member.contact, kind: "second_factor") }
    sign_in_pin(@member)

    post identity_second_factor_path, params: { second_factor: { code: current_code } }

    assert_response :too_many_requests
  end

  test "a sixth attempt in a minute receives 429" do
    sign_in_pin(@member)
    4.times { post identity_second_factor_path, params: { second_factor: { code: "000000" } } }

    post identity_second_factor_path, params: { second_factor: { code: "000000" } }
    post identity_second_factor_path, params: { second_factor: { code: "000000" } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /Trop de tentatives en une minute/
  end

  test "a verified team member is sent home" do
    sign_in_as @member

    get new_identity_second_factor_path

    assert_redirected_to team_home_path
  end

  test "a team member without a second factor is sent to the enrollment" do
    member = create_team_member(second_factor: false)
    sign_in_pin(member)

    get new_identity_second_factor_path

    assert_redirected_to new_identity_second_factor_enrollment_path
  end

  test "a visitor is sent to the sign-in page" do
    get new_identity_second_factor_path

    assert_redirected_to new_session_path
  end

  private

  def sign_in_pin(member) = post(session_path, params: { session: { contact: member.contact, pin: "2468" } })
  def current_code = ROTP::TOTP.new(@member.totp_secret).now
end
