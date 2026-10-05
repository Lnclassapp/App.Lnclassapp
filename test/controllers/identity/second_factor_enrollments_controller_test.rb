require "test_helper"

# ADR-0031: a team account activates TOTP with a first code; the backup codes are rendered once, never stored.
class Identity::SecondFactorEnrollmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member(second_factor: false)
    post session_path, params: { session: { contact: @member.contact, pin: "2468" } }
  end

  test "the enrollment shows a QR code and the secret" do
    get new_identity_second_factor_enrollment_path

    assert_response :success
    secret = Orm::TotpCredential.find_by!(user: @member).secret
    assert_select "[role=img] svg"
    assert_select "#second-factor-secret", text: secret.scan(/.{1,4}/).join(" ")
    assert_select "input[type=hidden][name='second_factor[secret]'][value=?]", secret
    assert_secret_response
  end

  # FU-12, FU-38, FU-39 (UDR-0054 §3.2, §3.4, §3.6): six digits leave by themselves, the page has a way out and says
  # what an authenticator app is. No field target: the QR code is read first.
  test "the enrollment sends the code at the sixth digit and offers a way out" do
    get new_identity_second_factor_enrollment_path

    assert_select "title", "Activer la vérification · Lnclass"
    assert_select "form#second-factor-enrollment-form[data-controller=autosubmit][data-autosubmit-pattern-value=?]" \
                  "[data-autosubmit-message-value=?]", '^\d{6}$', "Envoi du code…" do
      assert_select "input[name='second_factor[code]'][inputmode=numeric][maxlength='6'][pattern=?]" \
                    "[data-autosubmit-target=input][aria-describedby=second_factor_code_hint]", '\d{6}'
      assert_select "#second_factor_code_hint", text: "Le code est envoyé dès le 6ᵉ chiffre."
      assert_select "[data-autosubmit-target=status][aria-live=polite]"
    end
    assert_select "[data-autofocus-target]", 0
    assert_select "a[href=?][data-turbo-method=delete]", session_path, text: "Se déconnecter"
    assert_select "details summary .sr-only", text: "Aide : Application d'authentification"
    assert_select "details div", text: /Google Authenticator ou Microsoft Authenticator/
  end

  test "the first code activates the second factor and renders the backup codes" do
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: current_code) }

    assert_response :success
    assert_select "li", 10
    assert_select "title", "Codes de secours · Lnclass"
    assert_not_nil Orm::TotpCredential.find_by!(user: @member).confirmed_at
    assert_not_nil Orm::Session.find_by!(user: @member).second_factor_verified_at
    assert_empty flash.to_h
    assert_secret_response
  end

  # FU-40 to FU-43 (UDR-0054 §3.7): download, copy and print on a click only; « Continuer » needs « Je les ai gardés »,
  # and the box sends nothing.
  test "the backup codes are saved, copied or printed on demand, then kept before going on" do
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: current_code) }

    codes = css_select("#second-factor-enrollment ul li").map { |item| item.text.strip }
    assert_equal 10, codes.size
    assert_select "div.flex.flex-wrap.print\\:hidden[data-controller=download]" \
                  "[data-download-filename-value='lnclass-codes-de-secours.txt']" do |(actions)|
      content = actions["data-download-content-value"]
      assert_equal [ "Codes de secours Lnclass", I18n.l(Date.current, format: :long), "Chaque code ne sert qu'une fois.", "", *codes ],
                   content.split("\n")
      assert_select "button[hidden][data-download-target=button][data-action='download#save']", text: "Télécharger"
      assert_select "button[hidden][data-download-target=button][data-action='download#print']", text: "Imprimer"
      assert_select "template[data-download-target=saved]"
      assert_select "span[data-controller=clipboard]" do |(copy)|
        assert_equal codes.join("\n"), copy["data-clipboard-text-value"]
        assert_select "button[hidden][aria-label='Copier les codes de secours']", text: "Copier"
      end
    end
    assert_select "form#backup-codes-kept-form[method=get][action=?].print\\:hidden", team_home_path do
      assert_select "input[type=checkbox][required]#backup_codes_kept:not([name])"
      assert_select "label[for=backup_codes_kept].min-h-tap", text: "Je les ai gardés"
      assert_select "button[type=submit]", text: "Continuer"
      assert_select "input[name]", 0
    end
    assert_select "a[href=?]", team_home_path, 0
  end

  test "under Turbo, the backup codes replace the enrollment in place" do
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: current_code) },
                                                 as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream action="replace" target="second-factor-enrollment"/, response.body)
    assert_equal 10, response.body.scan("<li").size
    assert_secret_response(stream: true)
  end

  # Chantier enrolement-secret-stable: a reload or a second tab must not invalidate the QR code already scanned.
  test "the QR code scanned before reopening the enrollment still activates the second factor" do
    get new_identity_second_factor_enrollment_path
    scanned = enrollment_params(code: current_code)
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path, params: { second_factor: scanned }

    assert_response :success
    assert_select "li", 10
    assert_not_nil credential.confirmed_at
  end

  test "a wrong code re-renders the same QR code in 422" do
    get new_identity_second_factor_enrollment_path
    secret = Orm::TotpCredential.find_by!(user: @member).secret

    post identity_second_factor_enrollment_path, params: { second_factor: enrollment_params(code: "000000") }

    assert_response :unprocessable_entity
    assert_select "#second_factor_code_error", text: "Code incorrect."
    assert_select "#second-factor-secret", text: secret.scan(/.{1,4}/).join(" ")
    assert_select "[role=img] svg"
    assert_secret_response
  end

  test "a submitted address that is not a TOTP URI draws no QR code" do
    get new_identity_second_factor_enrollment_path

    post identity_second_factor_enrollment_path,
         params: { second_factor: enrollment_params(code: "000000").merge(secret_uri: "javascript:alert(1)") }

    assert_response :unprocessable_entity
    assert_select "[role=img] svg", 0
  end

  test "an enrolled team member is sent to the verification" do
    sign_out
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    get new_identity_second_factor_enrollment_path

    assert_redirected_to new_identity_second_factor_path
  end

  test "a signed-in student is sent home" do
    sign_out
    sign_in_as create_teacher

    get new_identity_second_factor_enrollment_path

    assert_redirected_to teacher_home_path
  end

  private

  def credential = Orm::TotpCredential.find_by!(user: @member)
  def current_code = ROTP::TOTP.new(credential.secret).now

  def enrollment_params(code:)
    { code:, secret: credential.secret, secret_uri: ROTP::TOTP.new(credential.secret, issuer: "Lnclass").provisioning_uri(@member.contact) }
  end
end
