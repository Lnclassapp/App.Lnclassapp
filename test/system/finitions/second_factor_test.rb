require "application_system_test_case"

# UDR-0054 §3.6, §3.7: the second factor leaves at the sixth digit, once; the backup code has its own field; the
# backup codes are downloaded, copied or printed on a click, and kept before going on.
module Finitions; end

class Finitions::SecondFactorTest < ApplicationSystemTestCase
  # FU-34, FU-39
  test "six digits of a valid code open the team home without a click, in one submission" do
    member = create_team_member
    reach_verification(member)
    count_submissions("second-factor-form")
    field = find_field("second_factor[code]")

    assert_equal "second_factor_code_hint", field["aria-describedby"]
    assert_selector "#second_factor_code_hint", text: "Le code est envoyé dès le 6ᵉ chiffre."
    assert_focused field
    field.send_keys(ROTP::TOTP.new(member.totp_secret).now)

    assert_arrived_on team_home_path
    assert_equal 1, submissions
  end

  # FU-35
  test "a wrong code comes back empty and focused, as one attempt, and nothing leaves until six digits again" do
    member = create_team_member
    reach_verification(member)

    assert_no_page_reload do
      find_field("second_factor[code]").send_keys(wrong_code(member))

      assert_selector "#second_factor_code_error", text: "Code incorrect."
    end
    assert_field "second_factor[code]", with: ""
    assert_focused find_field("second_factor[code]")
    assert_equal 1, second_factor_attempts(member)

    count_submissions("second-factor-form")
    find_field("second_factor[code]").send_keys("12345")
    sleep 0.4

    assert_equal 0, submissions
    assert_equal 1, second_factor_attempts(member)
  end

  # FU-36
  test "Enter right after the sixth digit sends one request" do
    member = create_team_member
    reach_verification(member)
    find_field("second_factor[code]").send_keys(wrong_code(member), :enter)

    assert_selector "#second_factor_code_error", text: "Code incorrect."
    sleep 0.4

    assert_equal 1, second_factor_attempts(member)
  end

  # FU-37
  test "the backup code has its own field, sent by « Vérifier » only" do
    member = create_team_member
    create_backup_code(user: member, code: "Hx3kP9wQ2m")
    reach_verification(member)
    click_on "J'utilise un code de secours"

    field = find_field("Code de secours")
    assert_focused field
    assert_current_path new_identity_second_factor_path(backup: 1)
    count_submissions("second-factor-form")
    field.send_keys("123456")
    sleep 0.4

    assert_equal 0, submissions
    field.set("Hx3kP9wQ2m")
    click_on "Vérifier"

    assert_arrived_on team_home_path
  end

  # FU-37: back to the application code, and a wrong backup code keeps its variant.
  test "a wrong backup code keeps the backup field, and the application code is one link away" do
    member = create_team_member
    reach_verification(member)
    click_on "J'utilise un code de secours"
    fill_in "Code de secours", with: "Zz9kP9wQ2m"
    click_on "Vérifier"

    assert_selector "#second_factor_code_error", text: "Code incorrect."
    assert_field "Code de secours", with: ""
    click_on "Utiliser le code de l'application"

    assert_current_path new_identity_second_factor_path
    assert_selector "#second_factor_code_hint", text: "Le code est envoyé dès le 6ᵉ chiffre."
  end

  # FU-38, FU-39, FU-43, FU-40
  test "the enrollment leaves at the sixth digit, shows the codes, and goes on only once they are kept" do
    member = create_team_member(second_factor: false)
    secret = reach_enrollment(member)
    stub_download_and_print
    field = find_field("second_factor[code]")

    assert_equal "second_factor_code_hint", field["aria-describedby"]
    field.send_keys(ROTP::TOTP.new(secret).now)

    assert_selector "#second-factor-enrollment li", count: 10, wait: SIGN_IN_WAIT
    assert_nil evaluate_script("window.savedAs")
    assert_nil evaluate_script("window.savedBlob")

    click_on "Continuer"

    assert_selector "#backup-codes-kept-form"
    assert_current_path new_identity_second_factor_enrollment_path
    assert evaluate_script("document.getElementById('backup_codes_kept').validity.valueMissing")

    check "Je les ai gardés"
    click_on "Continuer"

    assert_arrived_on team_home_path
  end

  # FU-41, FU-42
  test "the backup codes are downloaded, copied one per line, and printed" do
    member = create_team_member(second_factor: false)
    secret = reach_enrollment(member)
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
    stub_download_and_print
    find_field("second_factor[code]").send_keys(ROTP::TOTP.new(secret).now)
    assert_selector "#second-factor-enrollment li", count: 10, wait: SIGN_IN_WAIT
    codes = all("#second-factor-enrollment ul li").map(&:text)

    click_on "Télécharger"

    assert_toast "Fichier des codes de secours téléchargé."
    assert_equal "lnclass-codes-de-secours.txt", evaluate_script("window.savedAs")
    saved = page.evaluate_async_script("window.savedBlob.text().then(arguments[0])")
    assert saved.start_with?("Codes de secours Lnclass\n")
    assert_equal codes, saved.lines.map(&:chomp).last(10)

    click_on "Copier"

    assert_toast "Codes copiés."
    assert_equal codes.join("\n"), page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")

    click_on "Imprimer"

    assert evaluate_script("window.printed")
  end

  # FU-12
  test "the enrollment offers « Se déconnecter », which closes the session" do
    member = create_team_member(second_factor: false)
    reach_enrollment(member)
    click_on "Se déconnecter"

    assert_current_path root_path
    visit new_identity_second_factor_enrollment_path

    assert_current_path new_session_path
  end

  # FU-53
  test "the verification and the backup codes do not scroll sideways at 390 px" do
    with_mobile_viewport do
      reach_verification(create_team_member)

      assert_no_horizontal_scroll
      click_on "J'utilise un code de secours"

      assert_field "Code de secours"
      assert_no_horizontal_scroll

      sign_out
      secret = reach_enrollment(create_team_member(second_factor: false))

      assert_no_horizontal_scroll
      find_field("second_factor[code]").send_keys(ROTP::TOTP.new(secret).now)

      assert_selector "#second-factor-enrollment li", count: 10, wait: SIGN_IN_WAIT
      assert_selector "button", text: "Télécharger"
      assert_no_horizontal_scroll
    end
  end

  private

  def reach_verification(member)
    submit_pin(member)
    assert_selector "#second-factor-form", wait: SIGN_IN_WAIT
    assert_current_path new_identity_second_factor_path
  end

  # → the secret shown on the page, as an authenticator app reads it.
  def reach_enrollment(member)
    submit_pin(member)
    find("#second-factor-secret", wait: SIGN_IN_WAIT).text.delete(" ")
  end

  def submit_pin(member)
    visit new_session_path
    fill_in "session[contact]", with: member.contact
    fill_in "session[pin]", with: "2468"
    click_on I18n.t("identity.sessions.new.submit")
  end

  # Six digits that are not the code of the moment, nor of the step before or after.
  def wrong_code(member)
    totp = ROTP::TOTP.new(member.totp_secret)
    valid = [ -30, 0, 30 ].map { |shift| totp.at(Time.current + shift) }
    (0..9).map { |digit| digit.to_s * 6 }.find { |code| valid.exclude?(code) }
  end

  def second_factor_attempts(member) = Orm::LoginAttempt.where(contact: member.contact, kind: "second_factor").count

  def count_submissions(form_id)
    execute_script(<<~JS, form_id)
      const id = arguments[0]
      window.submissions = 0
      document.addEventListener("turbo:submit-start", (event) => { if (event.target.id === id) window.submissions++ })
    JS
  end

  def submissions = evaluate_script("window.submissions")

  def stub_download_and_print
    execute_script(<<~JS)
      URL.createObjectURL = (blob) => { window.savedBlob = blob; return "blob:backup-codes" }
      URL.revokeObjectURL = () => {}
      HTMLAnchorElement.prototype.click = function () { if (this.download) { window.savedAs = this.download } }
      window.print = () => { window.printed = true }
    JS
  end

  def assert_focused(element)
    assert_selector "##{element['id']}:focus"
  end

  def assert_no_horizontal_scroll
    assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=,
                    evaluate_script("document.documentElement.clientWidth")
  end

  def assert_arrived_on(path)
    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path path
  end
end
