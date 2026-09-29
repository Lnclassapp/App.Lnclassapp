require "application_system_test_case"

# CE-06, CE-07, FU-26 (ADR-0057, UDR-0044, UDR-0054): on a school's page, the team reads the school code, copies it and its sign-up link,
# and regenerates it from the ⋮ menu after a confirmation — without reloading the page. The old code stops working.
class Teams::SchoolCodeTest < ApplicationSystemTestCase
  HEADER = "teams.schools.header".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def clipboard = page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")

  test "CE-06: the code and its link are shown and copied, as displayed, without reloading the page" do
    visit school_path(@school.public_id)

    within "#school_code" do
      assert_selector "#school_code_value", exact_text: "K7M-4QZ"
      assert_selector "a#school_code_link", text: "/e/k7m4qz"
    end
    assert_no_page_reload do
      click_on I18n.t("#{HEADER}.copy_code")
      assert_toast I18n.t("shared.clipboard.copied_code")
      assert_equal "K7M-4QZ", clipboard

      click_on I18n.t("#{HEADER}.copy_link")
      assert_toast I18n.t("shared.clipboard.copied_link")
      assert_equal school_code_signup_url("k7m4qz", host: URI(current_url).host, port: URI(current_url).port), clipboard
    end
  end

  test "CE-07: « Régénérer le code » asks first; cancel keeps it, confirming replaces it and the old one is refused" do
    visit school_path(@school.public_id)

    assert_no_page_reload do
      click_menu_action("#school_header", I18n.t("#{HEADER}.regenerate_code"))
      within("#school_header dialog[open]") do
        assert_text "K7M-4QZ"
        click_on I18n.t("#{HEADER}.cancel")
      end
      assert_no_selector "#school_header dialog[open]"
      assert_equal "k7m4qz", @school.reload.school_code

      click_menu_action("#school_header", I18n.t("#{HEADER}.regenerate_code"))
      within("#school_header dialog[open]") { click_on I18n.t("#{HEADER}.confirm_regenerate") }

      assert_no_selector "#school_code_value", exact_text: "K7M-4QZ"
      new_code = Entities::School::SchoolCode.display(@school.reload.school_code)
      assert_toast I18n.t("teams.school_codes.update.done", code: new_code)
      assert_selector "#school_code_value", exact_text: new_code
      assert_no_selector "#school_header dialog[open]"
    end
    assert_not_equal "k7m4qz", @school.reload.school_code
    assert_nil Queries::School::SchoolCodePreviewQuery.new.call(code: "k7m4qz")
  end

  test "on a phone, the code block fits the width and the code is copied" do
    with_mobile_viewport do
      visit school_path(@school.public_id)

      assert_selector "#school_code_value", exact_text: "K7M-4QZ"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
      click_on I18n.t("#{HEADER}.copy_code")
      assert_toast I18n.t("shared.clipboard.copied_code")
    end
  end
end
