require "application_system_test_case"

# GD-01, GD-03 (ADR-0071, UDR-0056 §3.1, §3.2): the direction signs in, sees its three destinations, opens
# « Établissement », reads its teachers' sign-up link, copies it and finds it in the WhatsApp message; the « Classes par
# niveau » block follows. Then the same on a 390 px phone, from the bottom bar, without the page scrolling sideways.
class SchoolAdmin::SchoolTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    referential = seed_referential
    @school = create_school(name: "Lycée Moderne de Bouaké", school_code: "k7m4qz")
    create_classroom(school: @school, level: referential[:levels]["6eme"], name: "6ème 1")
    @admin = create_school_admin(school: @school, first_name: "Adjoua")
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")
  def t(key, **) = I18n.t("school_admin.schools.#{key}", **)
  def clipboard = page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")

  test "GD-01, GD-03: on a desktop, the direction opens « Établissement », copies its link and shares it on WhatsApp" do
    sign_in_as @admin

    assert_school_journey(nav: "aside nav")
  end

  test "GD-01, GD-03: on a 390 px phone, the same journey from the bottom bar, without horizontal scroll" do
    with_mobile_viewport do
      sign_in_as @admin

      assert_school_journey(nav: "nav.bottom-0")
    end
  end

  private

  def assert_school_journey(nav:)
    assert_selector "main#main", wait: SIGN_IN_WAIT
    within(nav) do
      assert_selector "a[href]", count: 3
      assert_no_selector "a[aria-disabled]"
      click_link tn(:school)
    end

    assert_current_path school_admin_school_path
    within(nav) { assert_selector "a[aria-current=page]", text: tn(:school) }
    assert_selector "h1", text: "Lycée Moderne de Bouaké"
    link = school_code_signup_url("k7m4qz", host: URI(current_url).host, port: URI(current_url).port)
    within "#school_link" do
      assert_selector "a#school_link_value", exact_text: link
      assert_selector "#school_code_value", exact_text: "K7M-4QZ"
      whatsapp = find_link(t("link.share_whatsapp"))
      assert whatsapp[:href].start_with?("https://wa.me/?text=")
      assert_equal t("link.share_message", school: "Lycée Moderne de Bouaké", link:), CGI.unescape(whatsapp[:href].delete_prefix("https://wa.me/?text="))
    end
    assert_no_page_reload do
      within("#school_link") { click_on t("link.copy") }
      assert_toast t("link.copied")
      assert_equal link, clipboard
    end
    assert_selector "#school_level_classrooms #level_classrooms_6eme", text: "6ème"
    assert_no_horizontal_scroll
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
