require "application_system_test_case"

# ADR-0031 (amendement 2026-09-29): the backup codes are shown once. After « Je les ai gardés » and « Continuer », Back must not
# bring them back from the Turbo cache: the page asks the server again, which sends an enrolled account home.
class Identity::SecretBackNavigationTest < ApplicationSystemTestCase
  test "after the backup codes, Back does not show them again" do
    member = create_team_member(second_factor: false)
    visit new_session_path
    fill_in "session[contact]", with: member.contact
    fill_in "session[pin]", with: "2468"
    click_on I18n.t("identity.sessions.new.submit")

    secret = find("#second-factor-secret", wait: SIGN_IN_WAIT).text.delete(" ")
    # The code leaves by itself at the sixth digit (UDR-0054 §3.6).
    fill_in "second_factor[code]", with: ROTP::TOTP.new(secret).now
    assert_selector "#second-factor-enrollment li", count: 10, wait: SIGN_IN_WAIT
    assert_selector "head meta[name=turbo-cache-control][content=no-cache]", visible: :all

    check I18n.t("identity.second_factor_enrollments.backup_codes.kept")
    click_on I18n.t("identity.second_factor_enrollments.backup_codes.continue")
    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path team_home_path

    page.go_back

    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path team_home_path
    assert_no_selector "#second-factor-enrollment"
  end
end
